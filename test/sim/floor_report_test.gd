extends GdUnitTestSuite
## The quota clearance report (spec §12).


func _result(cleared: bool, hands: int, run_heat: float) -> FloorResult:
	var result: FloorResult = FloorResult.new()
	result.cleared = cleared
	result.hands = hands
	result.run_heat = run_heat
	return result


func _add(report: FloorReport, result: FloorResult) -> void:
	report.add(0, "default", GameKind.Kind.BLACKJACK, 0, "straight_flat", result)


func test_rates_and_means() -> void:
	var report: FloorReport = FloorReport.new()
	_add(report, _result(true, 20, 4.0))
	_add(report, _result(false, 60, 10.0))
	_add(report, _result(false, 60, 16.0))
	_add(report, _result(true, 40, 30.0))
	var record: FloorReport.Record = report.records()[0]
	assert_float(record.clear_rate()).is_equal(0.5)
	assert_float(record.mean_hands()).is_equal(45.0)
	assert_float(record.mean_run_heat()).is_equal(15.0)
	# Three of the four floors end at or below 16.
	assert_int(record.run_heat_percentile(0.75)).is_equal(16)


func test_merged_shards_match_a_single_run() -> void:
	var args: Array[String] = ["--mode=floor", "--sessions=6", "--seed=4", "--bots=bold"]
	var whole: FloorReport = SimRun.floors(SimOptions.parse(PackedStringArray(args)))
	var merged: FloorReport = FloorReport.new()
	for index: int in 3:
		var shard: Array[String] = args.duplicate()
		shard.append("--shard=%d/3" % index)
		var part: FloorReport = SimRun.floors(SimOptions.parse(PackedStringArray(shard)))
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(part.to_dict()))
		merged.merge(FloorReport.from_dict(parsed))
	assert_str(merged.format()).is_equal(whole.format())


func test_ejected_counts_floors_ending_at_run_heat_100() -> void:
	# Spec §7.4, §11: run heat 100 ends the run.
	var report: FloorReport = FloorReport.new()
	_add(report, _result(true, 20, 120.0))
	_add(report, _result(true, 20, 100.0))
	_add(report, _result(false, 60, 99.5))
	_add(report, _result(false, 60, 10.0))
	assert_float(report.records()[0].ejected_rate()).is_equal(0.5)
