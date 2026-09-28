class_name SessionRunner
extends RefCounted
## Plays one measurement session (spec §12): bot sits down at a fresh table
## of game on a standard deck with every action unlocked, at heat floor 0,
## and plays up to hands hands. The session's randomness all comes from seed.

## Bankroll in table maximums for a dollars-per-heat session, deep enough
## that going broke never cuts one short.
const DEEP_BANKROLL: int = -1
const DEEP_BANKROLL_MAXES: int = 1000


## bankroll DEEP_BANKROLL means DEEP_BANKROLL_MAXES table maximums.
static func run(
	config: TuneConfig,
	bot: Bot,
	game: GameKind.Kind,
	stakes: TableStakes.Kind,
	floor_number: int,
	hands: int,
	seed: int,
	bankroll: int = DEEP_BANKROLL
) -> SessionResult:
	var table: Table = Table.from_config(config, game, stakes, floor_number)
	if bankroll == DEEP_BANKROLL:
		bankroll = table.table_max * DEEP_BANKROLL_MAXES
	var session: TableSession = TableSession.new(
		config,
		table,
		Deck.standard(DeckRules.from_config(config).min_size),
		ManipulationLayer.new(),
		ActionKit.everything(),
		GameRng.new(seed),
		bankroll,
		0.0
	)
	var result: SessionResult = SessionResult.new()
	bot.begin_session(session)
	while result.hands < hands and session.ended() == null:
		var bet: int = bot.opening_bet(session)
		var hand: HandActions = session.start_hand(bet, bot.baccarat_side(session))
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
		result.net += summary.net
		result.heat += summary.heat
	var end: SessionEnd = session.stand_up()
	result.end_reason = end.reason
	result.run_heat_added = end.run_heat_added
	return result
