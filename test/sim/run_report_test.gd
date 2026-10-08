extends GdUnitTestSuite
## The whole-run report (spec §7.4, §12): wins, ejections by the end of
## floor 2 and before floor 4, the floor reached, and dollars per heat.


func _result(won: bool, ejected: bool, floor_reached: int, dph: float) -> RunResult:
	var result: RunResult = RunResult.new()
	result.finished = true
	result.won = won
	result.ejected = ejected
	result.floor_reached = floor_reached
	result.dollars_per_heat = dph
	return result


func _four() -> RunReport:
	var report: RunReport = RunReport.new()
	for result: RunResult in [
		_result(false, true, 1, 100.0),
		_result(false, true, 3, 200.0),
		_result(false, false, 4, 300.0),
		_result(true, false, 5, 400.0),
	]:
		report.add(0, "default", 0, "straight_flat", result)
	return report


func test_rates_and_means() -> void:
	var record: RunReport.Record = _four().records()[0]
	assert_int(record.runs).is_equal(4)
	assert_float(record.rate(record.won)).is_equal(0.25)
	assert_float(record.rate(record.ejected)).is_equal(0.5)
	assert_float(record.rate(record.ejected_by_floor_2)).is_equal(0.25)
	assert_float(record.rate(record.ejected_before_floor_4)).is_equal(0.5)
	assert_float(record.mean_floor()).is_equal(3.25)
	assert_float(record.mean_dollars_per_heat()).is_equal(250.0)


func test_shards_merge_to_the_whole() -> void:
	var merged: RunReport = RunReport.new()
	merged.merge(_four())
	merged.merge(_four())
	var record: RunReport.Record = merged.records()[0]
	assert_int(record.runs).is_equal(8)
	assert_int(record.ejected_by_floor_2).is_equal(2)
	assert_float(record.mean_dollars_per_heat()).is_equal(250.0)


func test_the_report_round_trips_through_json() -> void:
	var report: RunReport = _four()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(report.to_dict()))
	assert_str(RunReport.from_dict(parsed).format()).is_equal(report.format())


func test_the_format_lists_each_bot() -> void:
	var text: String = _four().format()
	assert_str(text).contains("== default ==")
	assert_str(text).contains("straight_flat")
	assert_str(text).contains("ej by F2")
