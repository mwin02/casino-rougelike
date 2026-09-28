extends GdUnitTestSuite
## The min-bet cooler and the reckless chaser (spec §1.6, §7.4, §12).

func _report(bots: String) -> SimReport:
	var args: Array[String] = ["--sessions=20", "--hands=10", "--seed=8", "--bots=" + bots]
	return SimRun.dollars_per_heat(SimOptions.parse(PackedStringArray(args)))


func test_the_cooler_alternates_the_maximum_and_the_minimum() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, ["10S", "10H"])
	var bot: MinBetCoolerBot = MinBetCoolerBot.new()
	bot.begin_session(session, fixture.config, Deck.standard(0))
	var bets: Array[int] = []
	for i: int in 4:
		bets.append(bot.opening_bet(session))
	var high: int = TableSessionFixture.TABLE_MAX
	var low: int = TableSessionFixture.TABLE_MIN
	assert_array(bets).contains_exactly([high, low, high, low])


func test_the_cooler_reveals_on_half_its_hands() -> void:
	var report: SimReport = _report("min_bet_cooler,reveal_only")
	for game: int in GameKind.Kind.values():
		var kind: GameKind.Kind = game as GameKind.Kind
		var cooler: SimReport.Record = report.record(0, kind, "min_bet_cooler")
		var every_hand: SimReport.Record = report.record(0, kind, "reveal_only")
		assert_float(cooler.heat_per_hand()).is_greater(0.0)
		assert_float(cooler.heat_per_hand()).is_less(every_hand.heat_per_hand())


func test_the_reckless_chaser_runs_hotter_than_a_reveal_and_adjust() -> void:
	var report: SimReport = _report("reckless_chaser,reveal_adjust")
	for game: int in GameKind.Kind.values():
		var kind: GameKind.Kind = game as GameKind.Kind
		var reckless: SimReport.Record = report.record(0, kind, "reckless_chaser")
		assert_float(reckless.heat_per_hand()).is_greater(
			report.record(0, kind, "reveal_adjust").heat_per_hand()
		)
		assert_int(reckless.backed_off).is_greater(0)
