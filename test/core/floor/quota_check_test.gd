extends GdUnitTestSuite
## The quota check at the end of the walk (spec §6.2, §6.5): a bankroll at
## or above the quota passes and is kept, not paid. Money spent or lost
## mid-floor counts against it. Passing floor 5 wins the run.

const QUOTA: int = 140_000

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new(QUOTA)


func _walk_to_the_end(floor: Floor) -> void:
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()


func test_the_check_waits_for_the_end_of_the_walk() -> void:
	var floor: Floor = _f.three_rows()
	assert_object(floor.check_quota()).is_null()
	floor.enter(floor.map.node_at(0, 1))
	assert_object(floor.check_quota()).is_null()


func test_reaching_the_quota_passes_and_keeps_the_bankroll() -> void:
	_f.run.bankroll = QUOTA + 5_000
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	var check: QuotaCheck = floor.check_quota()
	assert_int(check.result).is_equal(QuotaCheck.Result.PASSED)
	assert_int(check.fronted).is_equal(0)
	assert_int(_f.run.bankroll).is_equal(QUOTA + 5_000)
	assert_int(floor.phase).is_equal(Floor.Phase.END_SHOP)
	assert_bool(_f.run.marker_used).is_false()


func test_the_check_happens_once() -> void:
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	assert_object(floor.check_quota()).is_null()


func test_mid_floor_spending_counts_against_the_quota() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	var price: int = floor.services.price(DeckServices.Service.REMOVE)
	floor.services.remove(0)
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	var check: QuotaCheck = floor.check_quota()
	assert_int(check.result).is_equal(QuotaCheck.Result.MARKER)
	assert_int(check.fronted).is_equal(price)


func test_passing_floor_5_wins_the_run() -> void:
	_f.run.floor_number = 5
	_f.run.bankroll = _f.config.get_int_list("floors", "quotas")[4]
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	assert_int(floor.check_quota().result).is_equal(QuotaCheck.Result.WON)
	assert_bool(_f.run.won).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)
	assert_object(floor.shop).is_null()


func test_the_quota_carries_last_floors_marker_debt() -> void:
	_f.run.quota_carry = 30_000
	var floor: Floor = _f.three_rows()
	assert_int(floor.quota).is_equal(QUOTA + 30_000)
	assert_bool(floor.can_cash_out()).is_false()
