extends GdUnitTestSuite
## The side-bet bots (spec §8, §12): the gambler bets every side bet at the
## cap with a flat minimum; the chaser does too, and in every window takes
## each manipulation that raises the side bets' value.

var _fixture: TableSessionFixture


func before_test() -> void:
	_fixture = TableSessionFixture.new()


func _sit(codes: Array[String], bankroll: int = TableSessionFixture.BANKROLL) -> TableSession:
	return _fixture.sit(GameKind.Kind.BLACKJACK, codes, bankroll)


func test_the_gambler_bets_every_side_bet_at_the_cap() -> void:
	var session: TableSession = _sit(["7H", "10", "7D", "9", "K", "K"])
	var bot: SideGamblerBot = SideGamblerBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var bets: Array[SideBet] = bot.side_bets(session)
	assert_int(bets.size()).is_equal(3)
	for bet: SideBet in bets:
		assert_int(bet.stake).is_equal(session.side_bet_cap())
	assert_bool(session.can_start_hand(bot.opening_bet(session), bets)).is_true()


func test_the_gambler_bets_only_what_the_bankroll_covers() -> void:
	var cap: int = SideBetRules.from_config(_fixture.config).cap(TableSessionFixture.TABLE_MAX)
	var bankroll: int = TableSessionFixture.TABLE_MIN + cap
	var session: TableSession = _sit(["7H", "10", "7D", "9", "K", "K"], bankroll)
	var bot: SideGamblerBot = SideGamblerBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var bets: Array[SideBet] = bot.side_bets(session)
	assert_int(bets.size()).is_equal(1)
	assert_bool(session.can_start_hand(bot.opening_bet(session), bets)).is_true()


func test_the_chaser_manipulates_to_win_a_side_bet() -> void:
	# Player 7H 8D: a Nudge of the 8D down makes Perfect Pairs.
	var session: TableSession = _sit(["7H", "10", "8D", "9", "K", "K", "K", "K"])
	var bot: SideChaserBot = SideChaserBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	var summary: HandSummary = session.finish_hand()
	var side_heat: bool = summary.lines.any(
		func(line: HeatLine) -> bool: return line.kind == HeatLine.Kind.SIDE_BET
	)
	assert_bool(side_heat).is_true()
	assert_int(summary.side_net).is_greater(0)


func test_the_session_runner_counts_side_stakes() -> void:
	var result: SessionResult = SessionRunner.run(
		_fixture.config, SideGamblerBot.new(), GameKind.Kind.BLACKJACK,
		TableStakes.Kind.HIGH, 1, 5, 3
	)
	var table: Table = Table.from_config(
		_fixture.config, GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, 1
	)
	var per_hand: int = table.table_min + 3 * SideBetRules.from_config(_fixture.config).cap(
		table.table_max
	)
	assert_int(result.staked).is_equal(5 * per_hand)
