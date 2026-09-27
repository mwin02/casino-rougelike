extends GdUnitTestSuite
## Leaving a table rolls table heat into run heat (spec §7.3): only heat
## above the heat floor, 50% on standing up and 100% on being backed off.
## Going broke rolls over like standing up (block 7).

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


func _share() -> float:
	return _f.config.get_float("run_heat", "stand_up_rollover")


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


## §7.3 [TUNE]: 50% to start.
func test_standing_up_rolls_over_half() -> void:
	var session: TableSession = _sit()
	session.table_heat.heat = 30.0
	assert_float(_share()).is_equal(0.5)
	assert_float(session.stand_up().run_heat_added).is_equal_approx(15.0, 0.0001)


## §7.1: min-bet cooling can't pull 95 back under 90.
func test_backed_off_rolls_over_everything_above_the_floor() -> void:
	var session: TableSession = _sit(TableSessionFixture.BANKROLL, 10.0)
	session.table_heat.heat = 95.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	assert_float(end.run_heat_added).is_equal_approx(session.table_heat.heat - 10.0, 0.0001)


func test_going_broke_rolls_over_like_standing_up() -> void:
	var session: TableSession = _sit(TableSessionFixture.BET + TableSessionFixture.BET / 4)
	session.table_heat.heat = 40.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BROKE)
	assert_float(end.run_heat_added).is_equal_approx(session.table_heat.heat * _share(), 0.0001)
