extends GdUnitTestSuite
## What a run remembers for its summary (block U4, spec §11): how each floor
## ended, with its quota and the bankroll then, and the highest run heat
## reached. Both save with the run.

const QUOTA: int = 140_000

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new(QUOTA)


## Leaves the first table with this bankroll and table heat.
func _leave_table_with(floor: Floor, bankroll: int, heat: float = 0.0) -> void:
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	session.bankroll = bankroll
	session.table_heat.heat = heat
	floor.leave()


func _only_record() -> FloorRecord:
	assert_int(_f.run.records.size()).is_equal(1)
	return _f.run.records[0]


func test_a_new_run_has_no_records() -> void:
	assert_array(_f.run.records).is_empty()
	assert_float(_f.run.run_heat_peak).is_equal(0.0)


func test_a_passed_check_records_the_floor_as_met() -> void:
	_f.run.bankroll = QUOTA + 5_000
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	var record: FloorRecord = _only_record()
	assert_int(record.floor_number).is_equal(1)
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.MET)
	assert_int(record.quota).is_equal(QUOTA)
	assert_int(record.bankroll).is_equal(QUOTA + 5_000)
	assert_int(record.loan).is_equal(0)


func test_the_record_keeps_the_bankroll_at_the_check_not_after_the_shop() -> void:
	_f.run.bankroll = QUOTA + 50_000
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	floor.shop.buy_tape()
	floor.finish()
	assert_int(_only_record().bankroll).is_equal(QUOTA + 50_000)
	assert_int(_only_record().floor_number).is_equal(1)


func test_a_marker_at_the_check_records_the_bankroll_before_the_loan() -> void:
	_f.run.bankroll = QUOTA - 10_000
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	floor.check_quota()
	var record: FloorRecord = _only_record()
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.MARKER)
	assert_int(record.bankroll).is_equal(QUOTA - 10_000)
	assert_int(record.loan).is_equal(10_000)


func test_a_floor_passed_on_a_broke_loan_records_the_marker() -> void:
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	var loan: int = floor.marker_loan
	_f.run.bankroll = QUOTA
	floor.cash_out()
	floor.check_quota()
	var record: FloorRecord = _only_record()
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.MARKER)
	assert_int(record.loan).is_equal(loan)


func test_a_failed_check_records_the_floor_as_short() -> void:
	_f.run.marker_used = true
	_f.run.bankroll = QUOTA - 10_000
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	floor.check_quota()
	var record: FloorRecord = _only_record()
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.SHORT)
	assert_int(record.bankroll).is_equal(QUOTA - 10_000)


func test_an_ejection_records_the_bankroll_when_ejected() -> void:
	_f.run.run_heat = 99.0
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 30_000, 20.0)
	assert_bool(_f.run.ejected).is_true()
	var record: FloorRecord = _only_record()
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.EJECTED)
	assert_int(record.bankroll).is_equal(30_000)


func test_going_broke_with_the_marker_used_records_the_floor_as_broke() -> void:
	_f.run.marker_used = true
	var floor: Floor = _f.three_rows()
	_leave_table_with(floor, 500)
	var record: FloorRecord = _only_record()
	assert_int(record.outcome).is_equal(FloorRecord.Outcome.BROKE)
	assert_int(record.bankroll).is_equal(500)


func test_the_peak_follows_run_heat_up_and_stays_when_it_sheds() -> void:
	_f.run.add_run_heat(30.0)
	_f.run.add_run_heat(12.0)
	_f.run.shed_run_heat(20.0)
	_f.run.add_run_heat(5.0)
	assert_float(_f.run.run_heat_peak).is_equal_approx(42.0, 0.0001)


func test_records_and_the_peak_save_with_the_run_state() -> void:
	_f.run.bankroll = QUOTA + 5_000
	_f.run.add_run_heat(33.0)
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	var loaded: RunState = RunState.from_dict(_f.run.to_dict())
	assert_float(loaded.run_heat_peak).is_equal_approx(33.0, 0.0001)
	assert_int(loaded.records.size()).is_equal(1)
	assert_dict(loaded.records[0].to_dict()).is_equal(_f.run.records[0].to_dict())
	assert_dict(loaded.to_dict()).is_equal(_f.run.to_dict())
