extends GdUnitTestSuite
## How a table session ends (block 7): the player stands up between hands,
## is backed off at 90 after the hand (spec §7.1), or goes broke below the
## table minimum. Session changes and once-per-session actions reset.
## Card i has id i.

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()
	_f.kit.masking_tape = 1


## High or Low on all 5s: the first call ties and loses half the stake.
func _sit(bankroll: int = TableSessionFixture.BANKROLL) -> TableSession:
	return _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4), bankroll)


func _tie_hand(session: TableSession) -> void:
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	session.finish_hand()


func _short_bankroll() -> int:
	return TableSessionFixture.BET + TableSessionFixture.BET / 4


func test_a_session_runs_until_it_ends() -> void:
	var session: TableSession = _sit()
	_tie_hand(session)
	assert_object(session.ended()).is_null()
	assert_bool(session.can_start_hand(TableSessionFixture.BET)).is_true()


func test_backed_off_ends_the_session_after_the_hand() -> void:
	var session: TableSession = _sit()
	session.table_heat.heat = 95.0
	_tie_hand(session)
	assert_int(session.ended().reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	assert_bool(session.can_start_hand(TableSessionFixture.BET)).is_false()
	assert_object(session.start_hand(TableSessionFixture.BET)).is_null()


func test_falling_below_the_table_minimum_ends_it_broke() -> void:
	var session: TableSession = _sit(_short_bankroll())
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BROKE)
	assert_int(end.bankroll).is_equal(_short_bankroll() - TableSessionFixture.BET / 2)
	assert_bool(session.can_start_hand(TableSessionFixture.TABLE_MIN)).is_false()


func test_backed_off_wins_over_broke() -> void:
	var session: TableSession = _sit(_short_bankroll())
	session.table_heat.heat = 95.0
	_tie_hand(session)
	assert_int(session.ended().reason).is_equal(SessionEnd.Reason.BACKED_OFF)


func test_stand_up_only_between_hands() -> void:
	var session: TableSession = _sit()
	session.start_hand(TableSessionFixture.BET)
	assert_object(session.stand_up()).is_null()
	assert_object(session.ended()).is_null()


func test_standing_up_reports_the_session() -> void:
	var session: TableSession = _sit()
	_tie_hand(session)
	_tie_hand(session)
	var end: SessionEnd = session.stand_up()
	assert_int(end.reason).is_equal(SessionEnd.Reason.STOOD_UP)
	assert_int(end.hands_played).is_equal(2)
	assert_int(end.net).is_equal(-TableSessionFixture.BET)
	assert_int(end.bankroll).is_equal(TableSessionFixture.BANKROLL - TableSessionFixture.BET)
	assert_bool(session.can_start_hand(TableSessionFixture.BET)).is_false()


func test_standing_up_again_changes_nothing() -> void:
	var session: TableSession = _sit()
	var end: SessionEnd = session.stand_up()
	assert_object(session.stand_up()).is_same(end)


## §2.3: a taped change lasts the session, then reverts.
func test_taped_changes_revert_when_the_session_ends() -> void:
	var session: TableSession = _sit()
	var actions: HandActions = session.start_hand(TableSessionFixture.BET)
	actions.nudge(1, 1)
	actions.tape(1)
	TableSessionFixture.play_out(session)
	session.finish_hand()
	assert_bool(_f.layer.is_taped(1)).is_true()
	session.stand_up()
	assert_int(_f.layer.size()).is_equal(0)


## §2.3: Palm works once per session.
func test_each_sit_down_starts_a_fresh_action_session() -> void:
	var session: TableSession = _sit()
	var actions: HandActions = session.start_hand(TableSessionFixture.BET)
	actions.palm(1, 13, Card.Suit.SPADES)
	assert_bool(actions.can_use(ActionKind.Kind.PALM)).is_false()
	var next: TableSession = _f.again(GameKind.Kind.HIGH_LOW)
	next.start_hand(TableSessionFixture.BET)
	assert_bool(next.current_hand().can_use(ActionKind.Kind.PALM)).is_true()
