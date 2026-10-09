extends GdUnitTestSuite
## Leaving a table rolls table heat into run heat (spec §7.3): only heat
## above the heat floor, one share on standing up and a larger one on being
## backed off.
## Going broke rolls over like standing up (block 7).

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


func _share() -> float:
	return _f.config.get_float("run_heat", "stand_up_rollover")


func _backed_off_share() -> float:
	return _f.config.get_float("run_heat", "backed_off_rollover")


func _sit(bankroll: int = TableSessionFixture.BANKROLL, heat_floor: float = 0.0) -> TableSession:
	return _f.sit(
		GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4), bankroll, heat_floor
	)


## A straight High or Low hand: the first call ties, losing half the stake.
func _tie_hand(session: TableSession) -> void:
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	session.finish_hand()


func test_only_heat_above_the_floor_rolls_over() -> void:
	var session: TableSession = _sit(TableSessionFixture.BANKROLL, 12.0)
	session.table_heat.heat = 40.0
	var end: SessionEnd = session.stand_up()
	assert_float(end.run_heat_added).is_equal_approx((40.0 - 12.0) * _share(), 0.0001)


func test_heat_at_the_floor_rolls_nothing() -> void:
	var session: TableSession = _sit(TableSessionFixture.BANKROLL, 20.0)
	assert_float(session.stand_up().run_heat_added).is_equal(0.0)


## §7.3 [TUNE]: 10%.
func test_standing_up_rolls_over_a_tenth() -> void:
	var session: TableSession = _sit()
	session.table_heat.heat = 30.0
	assert_float(_share()).is_equal(0.1)
	assert_float(session.stand_up().run_heat_added).is_equal_approx(3.0, 0.0001)


## §7.1: min-bet cooling can't pull 140 back under 135.
## §7.3 [TUNE]: 40% to start.
func test_backed_off_rolls_over_its_own_share() -> void:
	# A floor of 30 keeps the rollover under the session cap.
	var session: TableSession = _sit(TableSessionFixture.BANKROLL, 30.0)
	session.table_heat.heat = 140.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_float(_backed_off_share()).is_equal(0.4)
	assert_int(end.reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	var expected: float = (session.table_heat.heat - 30.0) * _backed_off_share()
	assert_float(end.run_heat_added).is_equal_approx(expected, 0.0001)


func test_going_broke_rolls_over_like_standing_up() -> void:
	var session: TableSession = _sit(TableSessionFixture.BET + TableSessionFixture.BET / 4)
	session.table_heat.heat = 40.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BROKE)
	assert_float(end.run_heat_added).is_equal_approx(session.table_heat.heat * _share(), 0.0001)


func test_one_session_rolls_over_at_most_the_cap() -> void:
	# Spec §7.3: a single session can't sink a run, however hot the table.
	var cap: float = _f.config.get_float("run_heat", "max_rollover")
	var session: TableSession = _sit()
	session.table_heat.heat = 1000.0
	assert_float(session.stand_up().run_heat_added).is_equal(cap)
