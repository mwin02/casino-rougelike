extends GdUnitTestSuite
## The honest adjuster (spec §1.1, §12): sizes the bet on the cards showing,
## never acts. Its heat is all bet-change base, the number it measures.


func _report(extra: Array[String]) -> SimReport:
	var args: Array[String] = [
		"--sessions=20", "--hands=10", "--seed=5", "--bots=honest_adjuster"
	]
	args.append_array(extra)
	return SimRun.dollars_per_heat(SimOptions.parse(PackedStringArray(args)))


func _record(report: SimReport, variant: int, game: GameKind.Kind) -> SimReport.Record:
	return report.record(variant, game, "honest_adjuster")


## Plays one hand of stacked blackjack cards at opening and returns the round.
func _blackjack(codes: Array[String], opening: int) -> BlackjackRound:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, codes)
	var bot: HonestAdjusterBot = HonestAdjusterBot.new()
	# The bot prices on a standard deck, not the few stacked cards.
	bot.begin_session(session, fixture.config, Deck.standard(0))
	bot.play_hand(session, session.start_hand(opening))
	return session.current_round()


func test_it_opens_at_the_minimum_and_changes_the_bet() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var report: SimReport = _report([])
	for game: GameKind.Kind in [GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT]:
		var record: SimReport.Record = _record(report, 0, game)
		var table: Table = Table.from_config(config, game, TableStakes.Kind.HIGH, 1)
		assert_int(record.staked).is_equal(record.hands * table.table_min)
		assert_float(record.heat_per_hand()).is_greater(0.0)


func test_high_or_low_gives_it_nothing_to_size_on() -> void:
	# Every call is priced at true odds less the cut (spec §3.3), so no card
	# up makes the first call worth raising, or bad enough to lower from the
	# minimum.
	var record: SimReport.Record = _record(_report([]), 0, GameKind.Kind.HIGH_LOW)
	assert_float(record.heat_per_hand()).is_equal(0.0)


func test_without_a_bet_change_base_it_costs_nothing() -> void:
	# Heat is (actions + base × changes) × m(r): with no base, any heat left
	# would be an action.
	for game: GameKind.Kind in [GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT]:
		var name: String = GameKind.config_section(game as GameKind.Kind)
		var report: SimReport = _report(
			["--games=%s" % name, "--set=%s.bet_change_base=0,4" % name]
		)
		assert_float(_record(report, 0, game).heat_per_hand()).is_equal(0.0)
		assert_float(_record(report, 1, game).heat_per_hand()).is_greater(0.0)


func test_it_sizes_up_on_a_strong_blackjack_hand() -> void:
	# Player 10, 10 (hard 20) against a dealer 6 up.
	var rnd: BlackjackRound = _blackjack(
		["10S", "6H", "10D", "10C", "5S", "5H", "5D", "5C"], TableSessionFixture.BET
	)
	assert_int(rnd.total_bet()).is_equal(3 * TableSessionFixture.BET)


func test_it_sizes_down_on_a_weak_blackjack_hand() -> void:
	# Player 10, 6 (hard 16) against a dealer ace up.
	var rnd: BlackjackRound = _blackjack(
		["10S", "AH", "6D", "10C", "10S", "10H", "10D", "10C"], 2 * TableSessionFixture.BET
	)
	assert_int(rnd.hands[0].stake).is_equal(rnd.limits.min_total())
