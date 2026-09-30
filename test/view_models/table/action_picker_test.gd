extends GdUnitTestSuite
## The action picker (spec §2.3, §2.5): action, then card, then option. Each
## step is a list of choices; an action runs when its last step is picked,
## and the picker goes back to the actions. Cards are labelled by the table
## (here with their codes). Blackjack piles deal player, dealer up, player,
## hole, so ids are: player 0 and 2, up card 1, hole card 3, next card 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _fixture: ActionsFixture
var _hand: HandActions
var _picker: ActionPicker


func before_test() -> void:
	_fixture = ActionsFixture.new()


func _start(rnd: GameRound, reveal_costs: bool = true) -> void:
	_hand = _fixture.actions(rnd)
	_picker = ActionPicker.new(_hand, _fixture.kit, _code, reveal_costs)


func _code(card: Card) -> String:
	return card.short_name()


func _labels() -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in _picker.choices():
		labels.append(choice.label)
	return labels


func _enabled(label: String) -> bool:
	for choice: Choice in _picker.choices():
		if choice.label == label:
			return choice.enabled
	return false


func _pick(label: String) -> void:
	for choice: Choice in _picker.choices():
		if choice.label == label:
			_picker.pick(choice.id)
			return
	fail("no choice labelled " + label)


func test_actions_list_every_action_with_its_cost() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	assert_array(_labels()).contains_exactly([
		"Partial reveal 2", "Mark 3", "Full reveal 4", "Look ahead 7",
		"Recolour 10", "Nudge 12", "Switch 20", "Palm 28",
	])


func test_actions_hide_costs_without_reveal_costs() -> void:
	_start(_fixture.blackjack(BLACKJACK), false)
	assert_str(_labels()[5]).is_equal("Nudge")


func test_locked_actions_are_disabled() -> void:
	_fixture.kit = ActionKit.starting()
	_start(_fixture.blackjack(BLACKJACK))
	assert_bool(_enabled("Partial reveal 2")).is_true()
	assert_bool(_enabled("Mark 3")).is_true()
	assert_bool(_enabled("Nudge 12")).is_true()
	assert_bool(_enabled("Full reveal 4")).is_false()
	assert_bool(_enabled("Palm 28")).is_false()


func test_nothing_is_enabled_outside_a_window() -> void:
	var rnd: BlackjackRound = _fixture.blackjack(BLACKJACK)
	_start(rnd)
	rnd.proceed()
	for choice: Choice in _picker.choices():
		assert_bool(choice.enabled).is_false()


func test_partial_reveal_asks_about_a_subject_card() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Partial reveal 2")
	assert_str(_picker.prompt_text()).is_equal("Partial reveal: choose a card")
	assert_array(_labels()).contains_exactly(["5C"])
	_pick("5C")
	assert_str(_picker.prompt_text()).is_equal("Partial reveal 5C: choose")
	assert_array(_labels()).contains_exactly(["Ten-card?", "Red?"])
	_pick("Red?")
	assert_array(_picker.info_lines).contains_exactly(["5C: red? no"])
	assert_int(_hand.used.size()).is_equal(1)
	assert_str(_picker.prompt_text()).is_equal("Choose an action")


func test_busts_me_is_asked_of_the_incoming_card() -> void:
	var rnd: BlackjackRound = _fixture.blackjack(BLACKJACK)
	_start(rnd)
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	_picker.reset()
	_pick("Partial reveal 2")
	_pick("2S")
	assert_array(_labels()).contains_exactly(["Busts me?", "Ten-card?", "Red?"])
	_pick("Busts me?")
	assert_array(_picker.info_lines).contains_exactly(["2S: busts me? no"])


func test_baccarat_questions() -> void:
	_start(_fixture.baccarat(["2S", "3H", "KD", "9C", "4S", "5H"]))
	# By kind: the label carries this game's tuned cost.
	_picker.pick(ActionKind.Kind.PARTIAL_REVEAL)
	assert_array(_labels()).contains_exactly(["KD", "9C"])
	_pick("9C")
	assert_array(_labels()).contains_exactly(["High?", "Face card?"])
	_pick("High?")
	assert_array(_picker.info_lines).contains_exactly(["9C: high? yes"])


func test_high_low_questions() -> void:
	_start(_fixture.high_low(["7S", "9H", "2C"]))
	_picker.pick(ActionKind.Kind.PARTIAL_REVEAL)
	_pick("9H")
	assert_array(_labels()).contains_exactly(["Within three?", "Red?"])
	_pick("Within three?")
	assert_array(_picker.info_lines).contains_exactly(["9H: within three? yes"])


func test_full_reveal_shows_the_card() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Full reveal 4")
	_pick("5C")
	assert_array(_picker.info_lines).contains_exactly(["5C is 5C"])


func test_look_ahead_needs_no_card() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Look ahead 7")
	assert_array(_picker.info_lines).contains_exactly(["Next: 2S 3H"])
	assert_str(_picker.prompt_text()).is_equal("Choose an action")


func test_mark_offers_each_symbol() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Mark 3")
	assert_array(_labels()).contains_exactly(["KS", "7D", "9H", "5C"])
	_pick("7D")
	assert_array(_labels()).contains_exactly(["*1", "*2"])
	_pick("*2")
	assert_int(_fixture.deck.card(2).symbol).is_equal(1)


func test_nudge_moves_a_rank() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Nudge 12")
	_pick("7D")
	assert_array(_labels()).contains_exactly(["Up", "Down"])
	_pick("Down")
	assert_array(_picker.info_lines).contains_exactly(["7D nudged down"])


func test_nudge_past_the_end_is_refused() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Nudge 12")
	_pick("KS")
	_pick("Up")
	assert_array(_picker.info_lines).contains_exactly(["Nudge refused"])
	assert_array(_hand.used).is_empty()


func test_nudge_below_an_ace_is_refused() -> void:
	_start(_fixture.blackjack(["AS", "9H", "7D", "5C", "2S"]))
	_pick("Nudge 12")
	_pick("AS")
	_pick("Down")
	assert_array(_picker.info_lines).contains_exactly(["Nudge refused"])
	assert_array(_hand.used).is_empty()


func test_recolour_offers_every_suit() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Recolour 10")
	_pick("7D")
	assert_array(_labels()).contains_exactly(["Clubs", "Diamonds", "Hearts", "Spades"])
	_pick("Spades")
	assert_array(_picker.info_lines).contains_exactly(["7D now spades"])


func test_switch_picks_a_second_card() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Switch 20")
	_pick("7D")
	assert_str(_picker.prompt_text()).is_equal("Switch 7D: choose the other card")
	assert_array(_labels()).contains_exactly(["KS", "9H", "5C"])
	_pick("5C")
	assert_array(_picker.info_lines).contains_exactly(["7D and 5C switched"])


func test_palm_picks_rank_then_suit_once_per_session() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Palm 28")
	_pick("5C")
	assert_array(_labels()).contains_exactly(
		["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	)
	_pick("Q")
	assert_str(_picker.prompt_text()).is_equal("Palm 5C to Q: choose a suit")
	_pick("Hearts")
	assert_array(_picker.info_lines).contains_exactly(["5C now QH"])
	assert_bool(_enabled("Palm 28")).is_false()


func test_back_steps_out_one_level() -> void:
	_start(_fixture.blackjack(BLACKJACK))
	_pick("Palm 28")
	_pick("5C")
	_pick("Q")
	_picker.back()
	assert_str(_picker.prompt_text()).is_equal("Palm 5C: choose a rank")
	_picker.back()
	assert_str(_picker.prompt_text()).is_equal("Palm: choose a card")
	_picker.back()
	assert_str(_picker.prompt_text()).is_equal("Choose an action")
	assert_bool(_picker.can_go_back()).is_false()
