extends GdUnitTestSuite
## A harness run (spec §12): a fixed seed gives an identical report every
## run, however many processes share the sessions.


func _options(extra: Array[String] = []) -> SimOptions:
	var args: Array[String] = ["--sessions=6", "--hands=5", "--seed=11"]
	args.append_array(extra)
	return SimOptions.parse(PackedStringArray(args))


func _run(options: SimOptions) -> SimReport:
	return SimRun.dollars_per_heat(options)


func test_a_fixed_seed_gives_the_same_report_every_run() -> void:
	var first: String = _run(_options()).format()
	assert_str(_run(_options()).format()).is_equal(first)


func test_merged_shards_match_a_single_run() -> void:
	var whole: SimReport = _run(_options())
	var merged: SimReport = SimReport.new()
	for index: int in 3:
		merged.merge(_run(_options(["--shard=%d/3" % index])))
	assert_str(merged.format()).is_equal(whole.format())


func test_the_report_survives_json() -> void:
	var report: SimReport = _run(_options())
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(report.to_dict()))
	assert_str(SimReport.from_dict(parsed).format()).is_equal(report.format())


func test_straight_flat_always_runs_as_the_baseline() -> void:
	var report: SimReport = _run(_options(["--bots=bold", "--games=baccarat"]))
	assert_object(report.record(0, GameKind.Kind.BACCARAT, "straight_flat")).is_not_null()
	assert_object(report.record(0, GameKind.Kind.BACCARAT, "bold")).is_not_null()


func test_one_record_per_variant_game_and_bot() -> void:
	var report: SimReport = _run(_options(["--set=heat.bet_change_base=0,4"]))
	assert_int(report.records().size()).is_equal(2 * 3 * BotRoster.names().size())


func test_bad_options_run_nothing() -> void:
	assert_object(_run(_options(["--bots=no_such_bot"]))).is_null()
	assert_object(_run(_options(["--set=heat.no_such_key=1"]))).is_null()
