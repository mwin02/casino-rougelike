extends GdUnitTestSuite
## The action picker as the real table's Tricks screen uses it: cards named
## in words, costs as whole numbers beside the names, and what a reveal
## showed drawn face up. Blackjack piles deal player, dealer up, player,
## hole, so ids are: player 0 and 2, up card 1, hole card 3, next card 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _vm: StackedTableScreenVM


func _deal(codes: Array[String] = BLACKJACK, game: GameKind.Kind = GameKind.Kind.BLACKJACK) -> void:
	_vm = StackedTableScreenVM.on(codes)
	_vm.setup.choose_game(game)
	_vm.sit_down()
	_vm.deal()


func _labels() -> Array[String]:
	return StackedTableDebugVM.labels(_vm.picker().choices())


func _card(id: int) -> CardView:
	for group: CardGroup in _vm.game().card_groups():
		for view: CardView in group.cards:
			if view.id == id:
				return view
	return null


func test_actions_show_their_names_with_whole_costs_beside_them() -> void:
	_deal()
	var choices: Array[Choice] = _vm.picker().choices()
	var hand: HandActions = _vm.session().current_hand()
	assert_str(choices[ActionKind.Kind.NUDGE].label).is_equal("Nudge")
	assert_str(choices[ActionKind.Kind.NUDGE].detail).is_equal(
		"+%d" % roundi(hand.cost_of(ActionKind.Kind.NUDGE))
	)
	for choice: Choice in choices:
		assert_bool(choice.detail.contains(".")).is_false()


func test_targets_are_named_in_words() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	assert_array(_labels()).contains_exactly_in_any_order(
		["Your K", "Dealer 9", "Your 7", "Hole card"]
	)
	_vm.picker().back()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	assert_array(_labels()).contains_exactly(["Hole card"])


func test_baccarats_face_down_cards_are_named_by_side() -> void:
	_deal(["9S", "2H", "KD", "3C"], GameKind.Kind.BACCARAT)
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	assert_array(_labels()).contains_exactly(["Player 2nd", "Banker 2nd"])


func test_the_card_about_to_be_dealt_is_on_the_table_as_a_target() -> void:
	_deal()
	_vm.proceed()
	_vm.play(BlackjackTableVM.Play.HIT)
	var groups: Array[CardGroup] = _vm.game().card_groups()
	assert_int(groups[-1].role).is_equal(CardGroup.Role.NEXT_CARD)
	assert_str(groups[-1].label).is_equal("Incoming card")
	assert_bool(groups[-1].cards[0].face_down).is_true()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	assert_array(_labels()).contains_exactly(["Incoming card"])


func test_a_full_reveal_turns_the_card_up_for_the_player_only() -> void:
	_deal()
	assert_bool(_card(3).face_down).is_true()
	_vm.picker().pick(ActionKind.Kind.FULL_REVEAL)
	_vm.picker().pick(3)
	var hole: CardView = _card(3)
	assert_bool(hole.face_down).is_false()
	assert_bool(hole.peeked).is_true()
	assert_str(hole.rank_text()).is_equal("5")
	assert_array(_vm.picker().info_lines).contains_exactly(["Hole card revealed"])
	assert_bool(_card(1).peeked).is_false()


func test_a_seen_card_follows_a_later_change() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.FULL_REVEAL)
	_vm.picker().pick(3)
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(3)
	_vm.picker().pick(ActionPicker.UP)
	assert_str(_card(3).rank_text()).is_equal("6")


func test_a_new_hand_forgets_what_was_seen() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.FULL_REVEAL)
	_vm.picker().pick(3)
	while _vm.in_hand():
		if _vm.can_proceed():
			_vm.proceed()
		else:
			_vm.play(BlackjackTableVM.Play.STAND)
	_vm.continue_after_hand()
	_vm.deal()
	assert_bool(_card(3).face_down).is_true()


func test_look_ahead_keeps_the_cards_it_showed() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.LOOK_AHEAD)
	var shown: Array[Card] = _vm.picker().shown_cards
	assert_int(shown.size()).is_equal(2)
	assert_str(shown[0].short_name()).is_equal("2S")
	assert_array(_vm.picker().info_lines).contains_exactly(["Next cards shown"])


func test_a_palm_reads_in_words() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.PALM)
	_vm.picker().pick(3)
	_vm.picker().pick(13)
	_vm.picker().pick(Card.Suit.SPADES)
	assert_array(_vm.picker().info_lines).contains_exactly(["Hole card now K of spades"])


func test_symbols_have_names() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.MARK)
	_vm.picker().pick(3)
	assert_str(_labels()[0]).is_equal("Star")


func test_the_meter_projects_the_action_being_weighed() -> void:
	_deal()
	assert_bool(_vm.meter().has_projection()).is_false()
	_vm.picker().pick(ActionKind.Kind.PALM)
	assert_float(_vm.picker().weighed_cost()).is_greater(0.0)
	assert_bool(_vm.meter().has_projection()).is_true()
	_vm.picker().back()
	assert_bool(_vm.meter().has_projection()).is_false()


func test_keeping_a_change_names_the_card_and_what_is_left() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(0)
	_vm.picker().pick(ActionPicker.DOWN)
	var keeps: Array[Choice] = _vm.picker().keep_choices()
	assert_str(keeps[ActionPicker.Keep.TAPE].label).is_equal("Tape")
	assert_str(keeps[ActionPicker.Keep.TAPE].detail).starts_with("×")
