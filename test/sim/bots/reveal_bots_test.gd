extends GdUnitTestSuite
## The reveal bots (spec §12): one full reveal on the key face-down card each
## hand, played into (reveal-only) or also sized on (reveal + adjust).


func _report(extra: Array[String]) -> SimReport:
	var args: Array[String] = [
		"--sessions=20", "--hands=10", "--seed=9", "--bots=reveal_only,reveal_adjust"
	]
	args.append_array(extra)
	return SimRun.dollars_per_heat(SimOptions.parse(PackedStringArray(args)))


func test_both_reveal_every_hand() -> void:
	var report: SimReport = _report([])
	var reveal: float = TuneConfig.load_default().get_float("actions", "full_reveal")
	for game: int in GameKind.Kind.values():
		for bot: String in ["reveal_only", "reveal_adjust"]:
			var record: SimReport.Record = report.record(0, game as GameKind.Kind, bot)
			# A table rolls the base at least 30% below its center (spec §1.2).
			assert_float(record.heat_per_hand()).is_greater(0.5 * reveal)


func test_reveal_only_never_adjusts() -> void:
	# Adjusts and side switches pay the bet-change base; doubles and splits
	# don't (spec §1.1). A bot that never adjusts pays the same at any base.
	for game: int in GameKind.Kind.values():
		var name: String = GameKind.config_section(game as GameKind.Kind)
		var report: SimReport = _report(
			["--games=%s" % name, "--set=%s.bet_change_base=0.0,4.0" % name]
		)
		var free: SimReport.Record = report.record(0, game as GameKind.Kind, "reveal_only")
		var dear: SimReport.Record = report.record(1, game as GameKind.Kind, "reveal_only")
		assert_float(dear.heat_per_hand()).is_equal(free.heat_per_hand())


func test_a_revealed_high_or_low_card_is_called_right() -> void:
	# Knowing the next card, a call only fails on a tie (half back), so the
	# bot always comes out ahead of straight play.
	var report: SimReport = _report(["--games=high_low"])
	var reveal: SimReport.Record = report.record(0, GameKind.Kind.HIGH_LOW, "reveal_only")
	assert_float(reveal.edge()).is_greater(0.2)


func test_sizing_on_the_reveal_earns_more() -> void:
	var report: SimReport = _report(["--games=high_low,blackjack"])
	for game: GameKind.Kind in [GameKind.Kind.HIGH_LOW, GameKind.Kind.BLACKJACK]:
		var only: SimReport.Record = report.record(0, game, "reveal_only")
		var sized: SimReport.Record = report.record(0, game, "reveal_adjust")
		assert_float(sized.ev_per_hand()).is_greater(only.ev_per_hand())
