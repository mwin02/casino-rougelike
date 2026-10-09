class_name RunRunner
extends RefCounted
## Plays a whole run, floor 1 to floor 5, with one bot (spec §5.3, §7.4,
## §11, §12). The run's randomness all comes from seed.
##
## The route is plain: cash out once the bankroll reaches the bot's
## cash-out share of the quota; otherwise enter a table node of the stakes
## the bankroll covers, high first, else low, else whatever comes next. At
## a table the bot sits at the first table it plays and can afford, and
## plays until the session ends, it reaches its cash-out share, the clock
## runs out, or table heat reaches the player's nerve (§12), drawn once per
## run and moved a little each session. Shops and deck services buy
## nothing. A sweep gives up the first thing offered; the elevator takes
## the first option.

## A run that takes more moves than this is stuck.
const MAX_MOVES: int = 10000


## Who plays the run: the bot, its nerve, and its cash-out share.
class Player:
	var bot_name: String
	var nerve: Nerve
	var cash_out_pct: int

	## The bankroll the player cashes out at on this floor.
	func target(floor: Floor) -> int:
		return Money.apply_ratio(floor.quota, cash_out_pct, 100)


## cash_out_pct SimOptions.BOTS_CASH_OUT is the bot's own share.
static func run(
	config: TuneConfig,
	bot_name: String,
	seed: int,
	items: Array[ItemKind.Kind] = [],
	cash_out_pct: int = SimOptions.BOTS_CASH_OUT
) -> RunResult:
	var game: Run = Run.start(config, seed, FloorRunner.harness_kit(config, items))
	var player: Player = Player.new()
	player.bot_name = bot_name
	player.nerve = Nerve.draw(seed)
	player.cash_out_pct = (
		BotRoster.build([bot_name])[0].cash_out_pct()
		if cash_out_pct == SimOptions.BOTS_CASH_OUT
		else cash_out_pct
	)
	var result: RunResult = RunResult.new()
	result.floor_bankrolls[0] = game.state.bankroll
	for move: int in MAX_MOVES:
		if game.phase == Run.Phase.WON or game.phase == Run.Phase.LOST:
			break
		var floor_number: int = game.state.floor_number
		var before: Floor.Phase = game.floor.phase
		var hands: int = _move(config, game, player)
		if game.state.floor_number > floor_number:
			result.floor_bankrolls[game.state.floor_number - 1] = game.state.bankroll
		if result.end == RunResult.End.UNFINISHED and game.state.lost:
			result.end = _loss(game.state, before)
		result.hands += hands
		result.hands_by_floor[floor_number - 1] += hands
		result.peak_run_heat = maxf(result.peak_run_heat, game.state.run_heat)
		if move == MAX_MOVES - 1:
			push_error("RunRunner: %s is stuck" % bot_name)
	result.finished = game.phase == Run.Phase.WON or game.phase == Run.Phase.LOST
	result.won = game.phase == Run.Phase.WON
	if result.won:
		result.end = RunResult.End.WON
	result.ejected = game.state.ejected
	result.floor_reached = game.state.floor_number
	result.bankroll = game.state.bankroll
	result.run_heat = game.state.run_heat
	result.dollars_per_heat = game.score().dollars_per_heat
	return result


## How a lost run ended, from the floor phase of the move that lost it.
static func _loss(state: RunState, before: Floor.Phase) -> RunResult.End:
	if state.ejected:
		return RunResult.End.EJECTED
	if before == Floor.Phase.QUOTA_CHECK:
		return RunResult.End.SHORT
	return RunResult.End.BROKE


## One move of the run. Returns the hands it played.
static func _move(config: TuneConfig, game: Run, player: Player) -> int:
	if game.phase == Run.Phase.ELEVATOR:
		game.ride(0)
		return 0
	var floor: Floor = game.floor
	match floor.phase:
		Floor.Phase.MAP:
			if floor.can_cash_out() and game.state.bankroll >= player.target(floor):
				floor.cash_out()
			else:
				floor.enter(_route(floor, game.state.bankroll))
		Floor.Phase.AT_TABLE:
			var hands: int = _play_table(config, game, player)
			floor.leave()
			return hands
		Floor.Phase.AT_STOP:
			floor.leave()
		Floor.Phase.SWEEP:
			floor.sweep(floor.sweep_choices()[0])
		Floor.Phase.QUOTA_CHECK:
			floor.check_quota()
		Floor.Phase.END_SHOP:
			floor.finish()
		Floor.Phase.DONE:
			game.end_floor()
	return 0


## The next node: a table node the bankroll covers, high stakes first.
static func _route(floor: Floor, bankroll: int) -> MapNode:
	var choices: Array[MapNode] = floor.choices()
	for stakes: TableStakes.Kind in [TableStakes.Kind.HIGH, TableStakes.Kind.LOW]:
		for node: MapNode in choices:
			if (
				node.kind == MapNode.Kind.TABLES
				and node.stakes == stakes
				and bankroll >= node.tables[0].table_min
			):
				return node
	return choices[0]


static func _play_table(config: TuneConfig, game: Run, player: Player) -> int:
	var floor: Floor = game.floor
	var bot: Bot = BotRoster.build([player.bot_name])[0]
	var session: TableSession = null
	for index: int in floor.current.tables.size():
		if bot.plays(floor.current.tables[index].game):
			session = floor.sit(index)
			if session != null:
				break
	if session == null:
		return 0
	bot.begin_session(session, config, game.game.deck)
	bot.take_nerve(player.nerve)
	var hands: int = 0
	while (
		session.ended() == null
		and session.bankroll < player.target(floor)
		and not floor.clock.is_out()
		and not bot.wants_to_stand(session)
	):
		var hand: HandActions = session.start_hand(
			bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
		)
		if hand == null:
			push_error("RunRunner: %s opened a refused bet" % player.bot_name)
			break
		bot.play_hand(session, hand)
		session.finish_hand()
		hands += 1
	return hands
