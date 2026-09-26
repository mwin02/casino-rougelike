extends GdUnitTestSuite
## Full reveal and look ahead (spec §2.3), and when any action is allowed:
## only in a window, and only once the kit unlocks it. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func test_full_reveal_shows_the_subject_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "QH"])
	var seen: Card = _f.actions(rnd).full_reveal(3)
	assert_str(seen.short_name()).is_equal("QH")


func test_full_reveal_only_on_a_subject_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "QH"])
	var actions: HandActions = _f.actions(rnd)
	assert_object(actions.full_reveal(0)).is_null()
	assert_array(actions.used).is_empty()


func test_full_reveal_gives_a_copy() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "QH"])
	var seen: Card = _f.actions(rnd).full_reveal(3)
	seen.rank = 2
	assert_int(rnd.dealer_hand.cards[1].rank).is_equal(12)


func test_look_ahead_shows_the_next_two_cards() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "2H", "3S", "4D"])
	var actions: HandActions = _f.actions(rnd)
	var seen: Array[Card] = actions.look_ahead()
	assert_array(ActionsFixture.ids(seen)).contains_exactly([4, 5])
	assert_str(seen[0].short_name()).is_equal("2H")
	assert_array(actions.used[0].card_ids).contains_exactly([4, 5])


func test_look_ahead_shows_what_is_left() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9"])
	assert_array(ActionsFixture.ids(_f.actions(rnd).look_ahead())).contains_exactly([1])


func test_actions_only_in_a_window() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "2"])
	rnd.proceed()
	var actions: HandActions = _f.actions(rnd)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		assert_bool(actions.can_use(action)).is_false()
	assert_array(actions.look_ahead()).is_empty()
	assert_bool(actions.mark(0, 0)).is_false()


func test_starting_kit_unlocks_partial_reveal_nudge_and_mark() -> void:
	_f.kit = ActionKit.starting()
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "2"])
	var actions: HandActions = _f.actions(rnd)
	var usable: Array[ActionKind.Kind] = []
	for action: ActionKind.Kind in ActionKind.Kind.values():
		if actions.can_use(action):
			usable.append(action)
	assert_array(usable).contains_exactly_in_any_order(
		[ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.MARK, ActionKind.Kind.NUDGE]
	)
	assert_object(actions.full_reveal(3)).is_null()
	assert_array(actions.look_ahead()).is_empty()


func test_reveals_target_subjects_and_marks_target_cards_in_play() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "2"])
	var actions: HandActions = _f.actions(rnd)
	var reveal: Array[Card] = actions.targets(ActionKind.Kind.FULL_REVEAL)
	var mark: Array[Card] = actions.targets(ActionKind.Kind.MARK)
	assert_array(ActionsFixture.ids(reveal)).contains_exactly([3])
	assert_array(ActionsFixture.ids(mark)).contains_exactly_in_any_order([0, 1, 2, 3])
