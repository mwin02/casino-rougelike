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


func test_one_record_per_variant_game_and_bot_that_plays_it() -> void:
	var report: SimReport = _run(_options(["--set=blackjack.bet_change_base=0,4"]))
	var played: int = 0
	for bot: Bot in BotRoster.build(BotRoster.default_names()):
		for game: int in GameKind.Kind.values():
			played += int(bot.plays(game as GameKind.Kind))
	assert_int(report.records().size()).is_equal(2 * played)
	assert_object(report.record(0, GameKind.Kind.BLACKJACK, "high_low_greedy")).is_null()


func test_bad_options_run_nothing() -> void:
	assert_object(_run(_options(["--bots=no_such_bot"]))).is_null()
	assert_object(_run(_options(["--set=heat.no_such_key=1"]))).is_null()


func test_side_bet_bots_run_only_when_named() -> void:
	var names: Array[String] = SimRun.bot_names(_options([]))
	for name: String in BotRoster.OPT_IN:
		assert_bool(name in names).is_false()
	assert_bool("side_gambler" in SimRun.bot_names(_options(["--bots=side_gambler"]))).is_true()
