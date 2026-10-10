extends GdUnitTestSuite
## The whole-run report (spec §7.4, §12): wins, ejections by the end of
## floor 2 and before floor 4, the floor reached, and dollars per heat.


func _result(
	won: bool,
	ejected: bool,
	floor_reached: int,
	dph: float,
	lost: RunResult.End = RunResult.End.SHORT
) -> RunResult:
	var result: RunResult = RunResult.new()
	result.finished = true
	if won:
		result.end = RunResult.End.WON
	elif ejected:
		result.end = RunResult.End.EJECTED
	else:
		result.end = lost
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
		_result(false, false, 2, 300.0, RunResult.End.BROKE),
		_result(true, false, 5, 400.0),
	]:
		report.add(0, "default", 0, "straight_flat", result)
	return report


func test_rates_and_means() -> void:
	var record: RunReport.Record = _four().records()[0]
	assert_int(record.runs).is_equal(5)
	assert_float(record.rate(record.won)).is_equal(0.2)
	assert_float(record.rate(record.ejected)).is_equal(0.4)
	assert_float(record.rate(record.ejected_by_floor_2)).is_equal(0.2)
	assert_float(record.rate(record.ejected_before_floor_4)).is_equal(0.4)
	assert_float(record.rate(record.lost_short)).is_equal(0.2)
	assert_float(record.rate(record.lost_broke)).is_equal(0.2)
	assert_float(record.rate(record.reached_floor_2)).is_equal(0.8)
	assert_float(record.rate(record.reached_floor_3)).is_equal(0.6)
	assert_float(record.mean_floor()).is_equal(3.0)
	assert_float(record.mean_dollars_per_heat()).is_equal(260.0)


func test_a_run_counts_toward_every_floor_it_reached() -> void:
	var record: RunReport.Record = _four().records()[0]
	assert_int(record.entered(1)).is_equal(5)
	assert_int(record.entered(2)).is_equal(4)
	assert_int(record.entered(3)).is_equal(3)
	assert_int(record.entered(4)).is_equal(2)
	assert_int(record.entered(5)).is_equal(1)


func test_the_pass_rate_is_of_the_runs_that_entered_the_floor() -> void:
	var record: RunReport.Record = _four().records()[0]
	assert_float(record.pass_rate(1)).is_equal(0.8)
	assert_float(record.pass_rate(2)).is_equal(0.75)
	assert_float(record.pass_rate(3)).is_equal_approx(2.0 / 3.0, 0.0001)
	assert_float(record.pass_rate(4)).is_equal(0.5)
	# Floor 5 is passed by winning the run.
	assert_float(record.pass_rate(5)).is_equal(1.0)


func test_a_floor_nobody_entered_has_no_pass_rate() -> void:
	var report: RunReport = RunReport.new()
	report.add(0, "default", 0, "straight_flat", _result(false, false, 1, 0.0))
	assert_float(report.records()[0].pass_rate(2)).is_equal(0.0)


func test_shards_merge_to_the_whole() -> void:
	var merged: RunReport = RunReport.new()
	merged.merge(_four())
	merged.merge(_four())
	var record: RunReport.Record = merged.records()[0]
	assert_int(record.runs).is_equal(10)
	assert_int(record.ejected_by_floor_2).is_equal(2)
	assert_int(record.lost_short).is_equal(2)
	assert_int(record.lost_broke).is_equal(2)
	assert_int(record.reached_floor_3).is_equal(6)
	assert_int(record.entered(4)).is_equal(4)
	assert_int(record.entered(5)).is_equal(2)
	assert_float(record.pass_rate(4)).is_equal(0.5)
	assert_float(record.mean_dollars_per_heat()).is_equal(260.0)


func test_the_report_round_trips_through_json() -> void:
	var report: RunReport = _four()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(report.to_dict()))
	assert_str(RunReport.from_dict(parsed).format()).is_equal(report.format())


func test_the_format_lists_each_bot() -> void:
	var text: String = _four().format()
	assert_str(text).contains("== default ==")
	assert_str(text).contains("straight_flat")
	assert_str(text).contains("ej by F2")
	assert_str(text).contains("short")
	assert_str(text).contains("broke")
	assert_str(text).contains("F3+")
	assert_str(text).contains("pass F4")
	assert_str(text).contains("50.0%")
