extends GdUnitTestSuite
## The marker (spec §11), once per run. When the walk ends short of the
## quota, or the player leaves a table below the floor's low-stakes minimum,
## the house fronts the shortfall up to max_share_pct of the quota. The
## loan plus interest_pct is added to the next floor's quota. A shortfall
## it can't cover, any failure once it's used, or failing floor 5 ends the
## run. Default config: 50%, 25% interest; floor 1 quota $140,000.

const QUOTA: int = 140_000
const CAP: int = 70_000

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new(QUOTA - 40_000)


func _short_check() -> QuotaCheck:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	return floor.check_quota()


## Sits at the first table and leaves it with bankroll left.
func _leave_table_with(floor: Floor, bankroll: int) -> void:
	floor.enter(floor.map.node_at(0, 1))
	floor.sit(0).bankroll = bankroll
	floor.leave()


func test_the_marker_fronts_a_shortfall_within_the_cap() -> void:
	var check: QuotaCheck = _short_check()
	assert_int(check.result).is_equal(QuotaCheck.Result.MARKER)
	assert_int(check.fronted).is_equal(40_000)
	assert_int(_f.run.bankroll).is_equal(QUOTA)
	assert_bool(_f.run.marker_used).is_true()


func test_the_marker_fronts_at_most_half_the_quota() -> void:
	_f.run.bankroll = QUOTA - CAP
	assert_int(_short_check().result).is_equal(QuotaCheck.Result.MARKER)
	var deeper: FloorFixture = FloorFixture.new(QUOTA - CAP - 1)
	_f = deeper
	var check: QuotaCheck = _short_check()
	assert_int(check.result).is_equal(QuotaCheck.Result.LOST)
	assert_int(check.fronted).is_equal(0)
	assert_bool(_f.run.lost).is_true()


func test_the_loan_plus_interest_joins_the_next_quota() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	floor.check_quota()
	floor.finish()
	assert_int(_f.run.quota_carry).is_equal(40_000 + 10_000)
	var next: Floor = _f.three_rows()
	assert_int(next.quota).is_equal(_f.config.get_int_list("floors", "quotas")[1] + 50_000)


func test_the_debt_is_repaid_once() -> void:
	_f.run.quota_carry = 50_000
	_f.run.bankroll = QUOTA + 50_000
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	floor.finish()
	assert_int(_f.run.quota_carry).is_equal(0)


func test_going_broke_fronts_the_cap_and_play_goes_on() -> void:
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)
	assert_int(_f.run.bankroll).is_equal(500 + CAP)
	assert_int(floor.marker_loan).is_equal(CAP)
	assert_bool(_f.run.marker_used).is_true()


func test_a_broke_loan_is_owed_when_the_floor_passes() -> void:
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	_f.run.bankroll = QUOTA
	floor.cash_out()
	assert_int(floor.check_quota().result).is_equal(QuotaCheck.Result.PASSED)
	floor.finish()
	assert_int(_f.run.quota_carry).is_equal(CAP + CAP / 4)


func test_leaving_a_table_at_the_low_stakes_minimum_is_not_broke() -> void:
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 1_000)
	assert_bool(_f.run.marker_used).is_false()
	assert_int(_f.run.bankroll).is_equal(1_000)


func test_a_second_failure_short_of_the_quota_ends_the_run() -> void:
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	var check: QuotaCheck = floor.check_quota()
	assert_int(check.result).is_equal(QuotaCheck.Result.LOST)
	assert_bool(_f.run.lost).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)


func test_a_second_failure_by_going_broke_ends_the_run() -> void:
	_f.run.marker_used = true
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	assert_bool(_f.run.lost).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)
	assert_array(floor.choices()).is_empty()


func test_a_used_marker_never_fronts_again() -> void:
	_f.run.marker_used = true
	assert_int(_short_check().result).is_equal(QuotaCheck.Result.LOST)
	assert_int(_f.run.bankroll).is_equal(QUOTA - 40_000)


func test_failing_floor_5_ends_the_run() -> void:
	_f.run.floor_number = 5
	_f.run.bankroll = _f.config.get_int_list("floors", "quotas")[4] - 1
	assert_int(_short_check().result).is_equal(QuotaCheck.Result.LOST)
	assert_bool(_f.run.marker_used).is_false()


func test_going_broke_on_floor_5_ends_the_run() -> void:
	_f.run.floor_number = 5
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	assert_bool(_f.run.lost).is_true()
	assert_bool(_f.run.marker_used).is_false()
	assert_int(_f.run.bankroll).is_equal(500)
