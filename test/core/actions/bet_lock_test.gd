extends GdUnitTestSuite
## The rescue rule (spec §2.2): any manipulation locks the bet for the rest of
## the hand, so no adjust, double, split, side switch or insurance after it.
## Knowledge never locks it. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func test_blackjack_locks_adjust_and_insurance() -> void:
	# Dealer ace up, so insurance would be offered.
	var rnd: BlackjackRound = _f.blackjack(["8", "A", "8", "7H", "5", "5"])
	_f.actions(rnd).recolour(3, Card.Suit.SPADES)
	rnd.proceed()
	assert_bool(rnd.can_adjust()).is_false()
	assert_bool(rnd.can_insure()).is_false()


func test_blackjack_locks_double_and_split() -> void:
	var rnd: BlackjackRound = _f.blackjack(["8", "A", "8", "7H", "5", "5"])
	_f.actions(rnd).nudge(3, 1)
	rnd.proceed()
	rnd.proceed()
	assert_bool(rnd.can_double()).is_false()
	assert_bool(rnd.can_split()).is_false()


func test_baccarat_locks_adjust_and_side_switch() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A", "A", "A"])
	_f.actions(rnd).nudge(2, 1)
	rnd.proceed()
	assert_bool(rnd.can_adjust()).is_false()
	assert_bool(rnd.can_switch_side()).is_false()


func test_high_low_locks_adjust() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
	_f.actions(rnd).palm(1, 13, Card.Suit.SPADES)
	rnd.proceed()
	assert_bool(rnd.can_adjust()).is_false()


func test_every_manipulation_locks() -> void:
	for action: ActionKind.Kind in ActionKind.MANIPULATION:
		before_test()
		var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7H", "5"])
		var actions: HandActions = _f.actions(rnd)
		match action:
			ActionKind.Kind.RECOLOUR:
				actions.recolour(3, Card.Suit.CLUBS)
			ActionKind.Kind.NUDGE:
				actions.nudge(3, 1)
			ActionKind.Kind.SWITCH:
				actions.switch_cards(3, 0)
			ActionKind.Kind.PALM:
				actions.palm(3, 1, Card.Suit.CLUBS)
		assert_bool(rnd.is_bet_locked()).is_true()


func test_knowledge_does_not_lock() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7H", "5"])
	var actions: HandActions = _f.actions(rnd)
	var asked: Array[PartialQuestion.Kind] = [PartialQuestion.Kind.RED]
	actions.partial_reveal(3, asked)
	actions.full_reveal(3)
	actions.look_ahead()
	actions.mark(3, 0)
	assert_bool(rnd.is_bet_locked()).is_false()


func test_a_refused_manipulation_does_not_lock() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "KH", "5"])
	_f.actions(rnd).nudge(3, 1)
	assert_bool(rnd.is_bet_locked()).is_false()
