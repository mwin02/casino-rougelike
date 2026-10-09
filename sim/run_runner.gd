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
## run and moved a little each session. The bot starts from the starting
## kit plus the unlocks its policy uses, and buys its wishlist at shops:
## mid-floor only past its cash-out share, at the end shop down to a share
## of the next quota. A sweep takes what it values least; the elevator
## takes the first option.

## A run that takes more moves than this is stuck.
const MAX_MOVES: int = 10000
## At the end shop a bot keeps this percent of the next floor's quota.
const KEEP_NEXT_QUOTA_PCT: int = 30


## Who plays the run: the bot (each table gets a fresh one), its run plan,
## its nerve, and its cash-out share.
class Player:
	var bot_name: String
	var plan: RunPlan
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
	var player: Player = Player.new()
	player.bot_name = bot_name
	player.plan = BotRoster.build([bot_name])[0].run_plan()
	player.nerve = Nerve.draw(seed)
	var game: Run = Run.start(config, seed, kit(config, player.plan, items))
	player.cash_out_pct = (
		player.plan.cash_out_pct
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


## The starting kit (§2.4) plus the plan's unlocks and items, in its slots;
## past them only if the given items need it.
static func kit(config: TuneConfig, plan: RunPlan, items: Array[ItemKind.Kind]) -> ActionKit:
	var result: ActionKit = ActionKit.starting()
	var rules: ItemRules = ItemRules.from_config(config)
	var wanted: Array[ItemKind.Kind] = plan.unlocks.duplicate()
	wanted.append_array(items)
	rules.slots = maxi(rules.slots, wanted.size())
	for item: ItemKind.Kind in wanted:
		result.add_item(item, rules)
	return result


## Buys the plan's wishlist items on offer, in order, keeping keep.
static func shop(stop: ShopStop, plan: RunPlan, keep: int) -> void:
	for item: ItemKind.Kind in plan.wishlist:
		if stop.can_buy_item(item) and stop.bankroll() - stop.item_price(item) >= keep:
			stop.buy_item(item)


## What a shop keeps: mid-floor, the plan's cash-out share of quota; at
## the end shop, a share of the next floor's quota.
static func holdback(
	config: TuneConfig, plan: RunPlan, quota: int, floor_number: int, end_shop: bool
) -> int:
	if not end_shop:
		return Money.apply_ratio(quota, plan.cash_out_pct, 100)
	var next: int = config.get_int_list("floors", "quotas")[floor_number]
	return Money.apply_ratio(next, KEEP_NEXT_QUOTA_PCT, 100)


static func _holdback(config: TuneConfig, player: Player, floor: Floor, end_shop: bool) -> int:
	return holdback(config, player.plan, floor.quota, floor.run.floor_number, end_shop)


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
				floor.enter(player.plan.route(floor.choices(), game.state.bankroll, game.game.deck))
		Floor.Phase.AT_TABLE:
			var hands: int = _play_table(config, game, player)
			floor.leave()
			return hands
		Floor.Phase.AT_STOP:
			if floor.shop != null:
				shop(floor.shop, player.plan, _holdback(config, player, floor, false))
			if floor.services != null:
				var keep: int = _holdback(config, player, floor, false)
				player.plan.use_services(floor.services, game.game.deck, keep)
			floor.leave()
		Floor.Phase.SWEEP:
			floor.sweep(player.plan.sweep_choice(floor.sweep_choices()))
		Floor.Phase.QUOTA_CHECK:
			floor.check_quota()
		Floor.Phase.END_SHOP:
			shop(floor.shop, player.plan, _holdback(config, player, floor, true))
			if floor.shop.services != null:
				var keep: int = _holdback(config, player, floor, true)
				player.plan.use_services(floor.shop.services, game.game.deck, keep)
			floor.finish()
		Floor.Phase.DONE:
			game.end_floor()
	return 0


static func _play_table(config: TuneConfig, game: Run, player: Player) -> int:
	var floor: Floor = game.floor
	var bot: Bot = BotRoster.build([player.bot_name])[0]
	var session: TableSession = null
	var high_min: int = (
		config.get_int_list("floors", "high_stakes_min")[game.state.floor_number - 1]
	)
	if not player.plan.sits_at(floor.current, game.state.bankroll, high_min):
		return 0
	for index: int in floor.current.tables.size():
		if bot.plays(floor.current.tables[index].game):
			session = floor.sit(index)
			if session != null:
				break
	if session == null:
		return 0
	bot.kit = game.kit
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
