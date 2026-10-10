class_name SessionRunner
extends RefCounted
## Plays one measurement session (spec §12): bot sits down at a fresh table
## of game on a standard deck with every action unlocked, at heat floor 0,
## and plays up to hands hands. The session's randomness all comes from seed.

## Bankroll in table maximums for a dollars-per-heat session, deep enough
## that going broke never cuts one short.
const DEEP_BANKROLL: int = -1
const DEEP_BANKROLL_MAXES: int = 1000


## bankroll DEEP_BANKROLL means DEEP_BANKROLL_MAXES table maximums. The table
## plays under house_rule when it fits the game.
static func run(
	config: TuneConfig,
	bot: Bot,
	game: GameKind.Kind,
	stakes: TableStakes.Kind,
	floor_number: int,
	hands: int,
	seed: int,
	bankroll: int = DEEP_BANKROLL,
	house_rule: String = ""
) -> SessionResult:
	var table: Table = Table.from_config(config, game, stakes, floor_number)
	table.house_rule = house_rule
	if bankroll == DEEP_BANKROLL:
		bankroll = table.table_max * DEEP_BANKROLL_MAXES
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	var session: TableSession = TableSession.new(
		config,
		table,
		deck,
		ManipulationLayer.new(),
		ActionKit.everything(),
		GameRng.new(seed),
		bankroll,
		0.0
	)
	var result: SessionResult = SessionResult.new()
	bot.begin_session(session, config, deck)
	while result.hands < hands and session.ended() == null:
		var bet: int = bot.opening_bet(session)
		var sides: Array[SideBet] = bot.side_bets(session)
		var hand: HandActions = session.start_hand(bet, bot.baccarat_side(session), sides)
		if hand == null:
			push_error("SessionRunner: %s opened a refused bet %d" % [bot.bot_name(), bet])
			break
		bot.play_hand(session, hand)
		var summary: HandSummary = session.finish_hand()
		if summary == null:
			push_error("SessionRunner: %s left a hand unresolved" % bot.bot_name())
			break
		result.hands += 1
		result.staked += bet
		for side: SideBet in sides:
			result.staked += side.stake
		result.net += summary.net
		result.heat += summary.heat
		result.cooling -= summary.cooling
	var end: SessionEnd = session.stand_up()
	result.end_reason = end.reason
	result.run_heat_added = end.run_heat_added
	return result
