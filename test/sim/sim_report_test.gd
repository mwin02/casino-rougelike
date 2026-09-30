extends GdUnitTestSuite
## The dollars-per-heat report's arithmetic and merging (spec §3.4, §12).


func _result(hands: int, net: int, heat: float, staked: int) -> SessionResult:
	var result: SessionResult = SessionResult.new()
	result.hands = hands
	result.net = net
	result.heat = heat
	result.staked = staked
	return result


func _add(report: SimReport, bot_index: int, bot: String, result: SessionResult) -> void:
	report.add(0, "default", GameKind.Kind.BLACKJACK, bot_index, bot, result)


func test_marginal_dollars_per_heat_is_gain_over_straight_per_heat() -> void:
	var report: SimReport = SimReport.new()
	_add(report, 0, "straight_flat", _result(10, -500, 0.0, 10000))
	_add(report, 1, "reader", _result(10, 1500, 40.0, 20000))
	var record: SimReport.Record = report.record(0, GameKind.Kind.BLACKJACK, "reader")
	assert_float(record.ev_per_hand()).is_equal(150.0)
	assert_float(record.heat_per_hand()).is_equal(4.0)
	assert_float(record.edge()).is_equal_approx(0.075, 1e-9)
	assert_float(record.dollars_per_heat()).is_equal(37.5)
	# (150 − (−50)) / 4
	assert_float(report.marginal_dollars_per_heat(record)).is_equal(50.0)


func test_no_heat_or_no_baseline_has_no_marginal_rate() -> void:
	var report: SimReport = SimReport.new()
	_add(report, 1, "reader", _result(10, 1500, 40.0, 20000))
	_add(report, 2, "bold", _result(10, -900, 0.0, 40000))
	var reader: SimReport.Record = report.record(0, GameKind.Kind.BLACKJACK, "reader")
	var bold: SimReport.Record = report.record(0, GameKind.Kind.BLACKJACK, "bold")
	assert_float(report.marginal_dollars_per_heat(reader)).is_equal(0.0)
	assert_float(bold.dollars_per_heat()).is_equal(0.0)


func test_sessions_add_up_and_merge_in_any_order() -> void:
	var results: Array[SessionResult] = [
		_result(5, 100, 1.1, 5000), _result(5, -300, 2.2, 5000), _result(4, 50, 3.3, 4000)
	]
	for i: int in results.size():
		results[i].cooling = 0.7 * (i + 1)
	var forward: SimReport = SimReport.new()
	var backward: SimReport = SimReport.new()
	for i: int in results.size():
		var part: SimReport = SimReport.new()
		_add(part, 1, "reader", results[i])
		forward.merge(part)
		var other: SimReport = SimReport.new()
		_add(other, 1, "reader", results[results.size() - 1 - i])
		backward.merge(other)
	var record: SimReport.Record = forward.record(0, GameKind.Kind.BLACKJACK, "reader")
	assert_int(record.sessions).is_equal(3)
	assert_int(record.hands).is_equal(14)
	assert_int(record.net).is_equal(-150)
	assert_float(record.heat_per_hand()).is_equal_approx(6.6 / 14.0, 1e-9)
	assert_float(record.cooling_per_hand()).is_equal_approx(4.2 / 14.0, 1e-9)
	assert_str(backward.format()).is_equal(forward.format())


func test_backed_off_sessions_are_counted() -> void:
	var report: SimReport = SimReport.new()
	var result: SessionResult = _result(3, -100, 95.0, 3000)
	result.end_reason = SessionEnd.Reason.BACKED_OFF
	_add(report, 1, "reckless", result)
	_add(report, 1, "reckless", _result(3, 0, 5.0, 3000))
	assert_int(report.record(0, GameKind.Kind.BLACKJACK, "reckless").backed_off).is_equal(1)


func test_cooling_is_heat_shed_per_hand() -> void:
	var report: SimReport = SimReport.new()
	var first: SessionResult = _result(6, 0, 12.0, 6000)
	first.cooling = 1.5
	var second: SessionResult = _result(4, 0, 8.0, 4000)
	second.cooling = 2.25
	_add(report, 1, "cooler", first)
	_add(report, 1, "cooler", second)
	var record: SimReport.Record = report.record(0, GameKind.Kind.BLACKJACK, "cooler")
	assert_float(record.cooling_per_hand()).is_equal_approx(0.375, 1e-9)
	assert_str(report.format()).contains("cool/h")
	assert_str(report.format()).contains("0.38")


func test_the_report_survives_json() -> void:
	var report: SimReport = SimReport.new()
	_add(report, 0, "straight_flat", _result(10, -500, 0.0, 10000))
	var reader: SessionResult = _result(10, 1500, 40.25, 20000)
	reader.cooling = 3.75
	_add(report, 1, "reader", reader)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(report.to_dict()))
	assert_str(SimReport.from_dict(parsed).format()).is_equal(report.format())
