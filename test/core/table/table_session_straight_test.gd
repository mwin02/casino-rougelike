extends GdUnitTestSuite
## A straight hand has no actions and no bet changes (spec §1.6), and only a
## straight hand cools. Card i has id i.

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


## Player 20 against a dealer 10 up: in the hole-card window.
func _blackjack() -> TableSession:
	var session: TableSession = _f.sit(
		GameKind.Kind.BLACKJACK, TableSessionFixture.repeat("10", 8)
	)
	session.start_hand(TableSessionFixture.BET)
	return session


func _cooled(summary: HandSummary) -> bool:
	for line: HeatLine in summary.lines:
		if line.kind == HeatLine.Kind.COOLING:
			return true
	return false


func test_hand_with_no_actions_or_changes_is_straight() -> void:
	var session: TableSession = _blackjack()
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_bool(summary.straight).is_true()
	assert_bool(_cooled(summary)).is_true()


func test_an_action_breaks_it() -> void:
	var session: TableSession = _blackjack()
	var hole: Card = session.current_round().window_subjects()[0]
	session.current_hand().full_reveal(hole.id)
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_bool(summary.straight).is_false()
	assert_bool(_cooled(summary)).is_false()


## A hand with only a bet change has no heat but is not straight.
func test_an_adjust_breaks_it() -> void:
	var session: TableSession = _blackjack()
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.adjust(2 * TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	assert_bool(session.finish_hand().straight).is_false()


func test_a_double_breaks_it() -> void:
	var session: TableSession = _blackjack()
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.proceed()
	rnd.double()
	TableSessionFixture.play_out(session)
	assert_bool(session.finish_hand().straight).is_false()


func test_a_refused_action_keeps_it() -> void:
	var session: TableSession = _blackjack()
	assert_object(session.current_hand().full_reveal(Card.NO_ID)).is_null()
	TableSessionFixture.play_out(session)
	assert_bool(session.finish_hand().straight).is_true()


## §3.3: the bet locking when a chain starts is not a bet change.
func test_a_high_low_chain_is_straight() -> void:
	var session: TableSession = _f.sit(
		GameKind.Kind.HIGH_LOW, ["2", "5", "9", "K"] as Array[String]
	)
	session.start_hand(TableSessionFixture.BET)
	var rnd: HighLowRound = session.current_round()
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	rnd.bank()
	var summary: HandSummary = session.finish_hand()
	assert_int(rnd.calls).is_equal(2)
	assert_bool(summary.straight).is_true()
