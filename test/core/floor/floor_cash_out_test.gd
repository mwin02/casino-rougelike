extends GdUnitTestSuite
## Cashing out (spec §6.5): once the bankroll reaches the quota, the player
## may stop between tables and skip to the quota check. Each unused hand
## sheds run heat, never below 0. Leaving the map's last row at or above the
## quota sheds the same way; running out of hands sheds nothing.

const QUOTA: int = 140_000

var _f: FloorFixture
var _per_hand: float


func before_test() -> void:
	_f = FloorFixture.new(QUOTA)
	_f.run.run_heat = 80.0
	_per_hand = _f.config.get_float("run_heat", "cash_out_shed_per_hand")


func test_the_quota_is_the_floors_configured_quota() -> void:
	assert_int(_f.three_rows().quota).is_equal(QUOTA)


func test_cash_out_is_refused_below_the_quota() -> void:
	_f.run.bankroll = QUOTA - 1
	var floor: Floor = _f.three_rows()
	assert_bool(floor.can_cash_out()).is_false()
	assert_bool(floor.cash_out()).is_false()
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_cash_out_is_only_between_tables() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.sit(0)
	assert_bool(floor.can_cash_out()).is_false()
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	assert_bool(floor.can_cash_out()).is_false()
	floor.leave()
	assert_bool(floor.can_cash_out()).is_true()


func test_cash_out_sheds_run_heat_per_unused_hand() -> void:
	var floor: Floor = _f.three_rows()
	floor.clock.hands_left = 12
	assert_bool(floor.cash_out()).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.QUOTA_CHECK)
	assert_float(floor.run_heat_shed).is_equal_approx(12 * _per_hand, 0.0001)
	assert_float(_f.run.run_heat).is_equal_approx(80.0 - 12 * _per_hand, 0.0001)


func test_cash_out_never_takes_run_heat_below_zero() -> void:
	_f.run.run_heat = 5.0
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	assert_float(_f.run.run_heat).is_equal(0.0)


func test_cash_out_skips_the_rest_of_the_map() -> void:
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	assert_array(floor.choices()).is_empty()
	assert_bool(floor.enter(floor.map.node_at(0, 1))).is_false()


func _walk_to_the_end(floor: Floor) -> void:
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()


func test_leaving_the_last_row_at_the_quota_sheds_unused_hands() -> void:
	var floor: Floor = _f.three_rows()
	var hands: int = floor.clock.hands_left
	_walk_to_the_end(floor)
	assert_float(_f.run.run_heat).is_equal_approx(maxf(80.0 - hands * _per_hand, 0.0), 0.0001)


func test_leaving_the_last_row_short_of_the_quota_sheds_nothing() -> void:
	_f.run.bankroll = QUOTA - 1
	var floor: Floor = _f.three_rows()
	_walk_to_the_end(floor)
	assert_float(floor.run_heat_shed).is_equal(0.0)
	assert_float(_f.run.run_heat).is_equal(80.0)


func test_running_out_of_hands_sheds_nothing() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.sit(0)
	floor.clock.hands_left = 1
	FloorFixture.play(floor, 1)
	var after_table: float = _f.run.run_heat
	floor.leave()
	assert_int(floor.phase).is_equal(Floor.Phase.QUOTA_CHECK)
	assert_float(floor.run_heat_shed).is_equal(0.0)
	assert_float(_f.run.run_heat).is_greater_equal(after_table)
