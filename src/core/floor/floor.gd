class_name Floor
extends RefCounted
## One floor of a run (spec §5.2, §6.1, §6.5). The player walks the floor
## map one row at a time along its links. At a table node they sit at one
## of its tables (or none) and play hands on the floor clock; at a shop or
## deck services they spend money but no hands. Leaving a node moves on.
##
## The walk ends at the quota check: after leaving the last row, after
## leaving a table once the clock is out, or on cashing out. Cashing out is
## open between tables once the bankroll reaches the quota and sheds run
## heat for each unused hand; so does finishing the map at the quota.
## Items lengthen the clock and carry unused hands on (§9), and Permanent
## Ink's charges refill as the floor starts. The
## bankroll and run heat live in the RunState and are banked on leaving a
## node.
##
## The quota is the floor's, plus last floor's marker debt. Passing the
## check opens the end shop, which never takes the bankroll below the next
## floor's low-stakes minimum; finishing banks it and moves the run up a
## floor. Falling short calls the marker (§11). So does leaving a table
## below this floor's low-stakes minimum, which fronts the capped amount and
## play goes on. A failure the marker can't cover, any failure once it's
## used, or failing (or going broke) on floor 5 loses the run.
##
## Run heat banked from a table can eject the player, before the marker is
## called (§7.4). Crossing the sweep threshold stops the floor until the
## player gives up an item or a symbol's marks (§7.6). From the pit boss's
## threshold he watches tables (§7.5): counted as the floor starts and each
## time run heat is banked, new ones drawn from rows the player hasn't
## reached.

enum Phase {
	## Choosing the next node.
	MAP,
	## At a table node, seated or not.
	AT_TABLE,
	## At a shop or deck services.
	AT_STOP,
	## The walk is over.
	QUOTA_CHECK,
	## Run heat crossed the sweep threshold: choosing what to lose.
	SWEEP,
	## Passed; at the end-of-floor shop.
	END_SHOP,
	## Finished, won or lost.
	DONE,
}

var phase: Phase = Phase.MAP
var run: RunState
var map: FloorMap
var clock: FloorClock
var quota: int
## The floor's signature pressure (§5.3).
var signature: FloorSignature
## The node the player is at or last left; null before the first row.
var current: MapNode
## The table session at the current table node, or null.
var session: TableSession
## The current shop node's stop or the end shop, or null.
var shop: ShopStop
## The current deck services node's services, or null.
var services: DeckServices
## Extra hands bought this floor for the next floor's clock.
var extra_hands_bought: int = 0
## Run heat shed by cashing out (or finishing the map at the quota).
var run_heat_shed: float = 0.0
## Unused hands Comped Breakfast carries to the next floor (§9). They shed
## no run heat.
var carried_hands: int = 0
## Dollars the marker fronted on this floor.
var marker_loan: int = 0
## Manipulations on this floor that raised the side bets' value: the
## side-bet heat repeat counts them across its tables (§8).
var side_bet_manipulations: int = 0
## The next floor's low-stakes minimum: the end shop's reserve.
var next_floor_min: int = 0

var _config: TuneConfig
var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _rng: GameRng
var _pricing: ShopPricing
var _run_heat: RunHeat
## Where the floor goes once the sweep is settled.
var _after_sweep: Phase = Phase.MAP
## Late Night hands this floor's clock already holds.
var _late_hands: int = 0


## map null rolls the floor's map from the run's FLOOR stream; signature
## null is the baseline. restoring skips what only a new floor does (Permanent
## Ink's refill, the pit boss's first count): from_dict sets the rest.
func _init(
	config: TuneConfig,
	p_run: RunState,
	deck: Deck,
	layer: ManipulationLayer,
	kit: ActionKit,
	rng: GameRng,
	p_map: FloorMap = null,
	p_signature: FloorSignature = null,
	restoring: bool = false
) -> void:
	_config = config
	run = p_run
	_deck = deck
	_layer = layer
	_kit = kit
	_rng = rng
	map = p_map
	if map == null:
		map = FloorMap.generate(config, run.floor_number, rng.stream(GameRng.Stream.FLOOR))
		map.roll_house_rules(
			config, run.floor_number, rng.stream(GameRng.Stream.HOUSE_RULES)
		)
	signature = p_signature if p_signature != null else FloorSignature.baseline()
	clock = FloorClock.new(
		signature.clock_hands(config.get_int("clock", "hands_per_floor"))
		+ run.extra_hands + run.carried_hands + kit.extra_floor_hands
	)
	_late_hands = kit.extra_floor_hands
	quota = config.get_int_list("floors", "quotas")[run.floor_number - 1] + run.quota_carry
	_pricing = ShopPricing.from_config(config, run.floor_number)
	_run_heat = RunHeat.from_config(config)
	if not restoring:
		kit.refill_ink()
		_watch()


## The floor between hands, for a save. The run, deck, layer, kit and RNG
## save with the run. Optional parts are lists of none or one. Never
## mid-hand (Run.can_save).
func to_dict() -> Dictionary:
	var shop_services: DeckServices = shop.services if shop != null else null
	return {
		"phase": phase,
		"map": map.to_dict(),
		"signature": signature.kind,
		"current": [] if current == null else [current.row, current.lane],
		"hands_left": clock.hands_left,
		"quota": quota,
		"extra_hands_bought": extra_hands_bought,
		"run_heat_shed": run_heat_shed,
		"carried_hands": carried_hands,
		"marker_loan": marker_loan,
		"side_bet_manipulations": side_bet_manipulations,
		"next_floor_min": next_floor_min,
		"late_hands": _late_hands,
		"after_sweep": _after_sweep,
		"shop": [] if shop == null else [shop.to_dict()],
		"shop_services": [] if shop_services == null else [shop_services.to_dict()],
		"services": [] if services == null else [services.to_dict()],
		"session": [] if session == null else [_session_dict()],
	}


static func from_dict(
	saved: Dictionary,
	config: TuneConfig,
	p_run: RunState,
	deck: Deck,
	layer: ManipulationLayer,
	kit: ActionKit,
	rng: GameRng
) -> Floor:
	var kind: int = saved["signature"]
	var saved_map: Dictionary = saved["map"]
	var floor: Floor = Floor.new(
		config, p_run, deck, layer, kit, rng, FloorMap.from_dict(saved_map),
		FloorSignature.of(config, kind as FloorSignature.Kind), true
	)
	var saved_phase: int = saved["phase"]
	floor.phase = saved_phase as Phase
	var at: Array = saved["current"]
	if not at.is_empty():
		var row: int = at[0]
		var lane: int = at[1]
		floor.current = floor.map.node_at(row, lane)
	floor.clock.hands_left = saved["hands_left"]
	floor.quota = saved["quota"]
	floor.extra_hands_bought = saved["extra_hands_bought"]
	floor.run_heat_shed = saved["run_heat_shed"]
	floor.carried_hands = saved["carried_hands"]
	floor.marker_loan = saved["marker_loan"]
	floor.side_bet_manipulations = saved["side_bet_manipulations"]
	floor.next_floor_min = saved["next_floor_min"]
	floor._late_hands = saved["late_hands"]
	var after: int = saved["after_sweep"]
	floor._after_sweep = after as Phase
	var saved_session: Array = saved["session"]
	for one: Dictionary in saved_session:
		floor._resume_session(one)
	var saved_services: Array = saved["services"]
	for one: Dictionary in saved_services:
		floor.services = floor._restore_services(one)
	var saved_shop: Array = saved["shop"]
	for one: Dictionary in saved_shop:
		var inner: DeckServices = null
		var shop_services: Array = saved["shop_services"]
		for inner_saved: Dictionary in shop_services:
			inner = floor._restore_services(inner_saved)
		floor.shop = ShopStop.from_dict(
			one, config, floor._pricing, kit, ItemRules.from_config(config), inner
		)
	return floor


## The nodes the player can enter next: the first row, then the current
## node's links. None away from the map.
func choices() -> Array[MapNode]:
	if phase != Phase.MAP:
		return []
	return map.row(0) if current == null else map.next_of(current)


func enter(node: MapNode) -> bool:
	if node not in choices():
		return false
	current = node
	match node.kind:
		MapNode.Kind.TABLES:
			phase = Phase.AT_TABLE
		MapNode.Kind.SHOP:
			phase = Phase.AT_STOP
			shop = ShopStop.new(_config, _pricing, run.bankroll, 0, extra_hands_bought)
			_stock(shop)
		MapNode.Kind.DECK_SERVICES:
			phase = Phase.AT_STOP
			services = DeckServices.new(
				DeckRules.from_config(_config), _deck, _kit, _pricing, run.bankroll,
				_rng.stream(GameRng.Stream.SHOP)
			)
	return true


## Sits at the current node's table at index, once per node, when the
## bankroll covers its minimum. Null when refused.
func sit(index: int) -> TableSession:
	if phase != Phase.AT_TABLE or session != null:
		return null
	if index < 0 or index >= current.tables.size():
		return null
	var table: Table = current.tables[index]
	if run.bankroll < table.table_min:
		return null
	session = TableSession.new(
		_config, table, _deck, _layer, _kit, _rng, run.bankroll,
		HeatFloor.of(_deck, _kit, DeckRules.from_config(_config)), clock, signature
	)
	session.carry_side_bet_manipulations(side_bet_manipulations)
	return session


## Leaves the current node, banking its money and run heat, and moves on.
## Refused mid-hand and away from a node.
func leave() -> bool:
	var swept: bool = false
	match phase:
		Phase.AT_TABLE:
			if session != null:
				var end: SessionEnd = session.stand_up()
				if end == null:
					return false
				var before: float = run.run_heat
				run.bankroll = end.bankroll
				run.add_run_heat(end.run_heat_added)
				run.heat_spent += end.session_heat
				side_bet_manipulations = session.side_bet_manipulations()
				session = null
				if _run_heat.ejects(run.run_heat):
					run.ejected = true
					_lose()
					return true
				_watch()
				swept = before < _run_heat.sweep_at and run.run_heat >= _run_heat.sweep_at
				if not _walk_ends() and _is_broke():
					_broke()
					_start_sweep(swept)
					return true
		Phase.AT_STOP:
			if shop != null:
				run.bankroll = shop.bankroll()
				extra_hands_bought = shop.extra_hands
				_give_late_hands()
			elif services != null:
				run.bankroll = services.bankroll
			shop = null
			services = null
		_:
			return false
	if clock.is_out():
		phase = Phase.QUOTA_CHECK
	elif _walk_ends():
		_finish_walk(run.bankroll >= quota)
	else:
		phase = Phase.MAP
	_start_sweep(swept)
	return true


## What the security sweep can take: each owned item, and each symbol with
## marks in the deck. Empty away from a sweep.
func sweep_choices() -> Array[SweepChoice]:
	var choices: Array[SweepChoice] = []
	if phase != Phase.SWEEP:
		return choices
	for item: ItemKind.Kind in _kit.items:
		choices.append(SweepChoice.of_item(item))
	var symbols: Array[int] = []
	for card: Card in _deck.cards():
		if card.is_marked() and card.symbol not in symbols:
			symbols.append(card.symbol)
	symbols.sort()
	for symbol: int in symbols:
		choices.append(SweepChoice.of_symbol(symbol))
	return choices


## Gives up choice to the sweep and goes on where the floor was headed.
## Refused for a choice the sweep doesn't offer.
func sweep(choice: SweepChoice) -> bool:
	if not sweep_choices().any(func(c: SweepChoice) -> bool: return c.same_as(choice)):
		return false
	if choice.kind == SweepChoice.Kind.ITEM:
		_kit.remove_item(choice.item)
		_give_late_hands()
	else:
		for card: Card in _deck.cards():
			if card.symbol == choice.symbol:
				_deck.clear_mark(card.id)
	phase = _after_sweep
	return true


## Between tables, once the bankroll has reached the quota.
func can_cash_out() -> bool:
	return phase == Phase.MAP and run.bankroll >= quota


## Skips the rest of the map; each unused hand sheds run heat.
func cash_out() -> bool:
	if not can_cash_out():
		return false
	_finish_walk(true)
	return true


func _finish_walk(shed: bool) -> void:
	phase = Phase.QUOTA_CHECK
	carried_hands = mini(clock.hands_left, _kit.carry_hands_max)
	if shed:
		var per_hand: float = _config.get_float("run_heat", "cash_out_shed_per_hand")
		run_heat_shed = run.shed_run_heat((clock.hands_left - carried_hands) * per_hand)


## Checks the bankroll against the quota once the walk is over; calls the
## marker when short. Null before the walk ends or once checked.
func check_quota() -> QuotaCheck:
	if phase != Phase.QUOTA_CHECK:
		return null
	var check: QuotaCheck = _check()
	if not check.passed():
		_lose()
	elif check.result == QuotaCheck.Result.WON:
		run.won = true
		phase = Phase.DONE
	else:
		_open_end_shop()
	return check


## Leaves the end shop: banks its bankroll, carries extra hands and marker
## debt to the next floor, and moves the run up a floor.
func finish() -> bool:
	if phase != Phase.END_SHOP:
		return false
	run.bankroll = shop.bankroll()
	run.extra_hands = shop.extra_hands
	run.carried_hands = carried_hands
	run.quota_carry = Marker.owed(_config, marker_loan)
	run.floor_number += 1
	shop = null
	phase = Phase.DONE
	return true


func _check() -> QuotaCheck:
	var last_floor: bool = run.floor_number == TuneSchema.FLOORS
	if run.bankroll >= quota:
		return QuotaCheck.new(QuotaCheck.Result.WON if last_floor else QuotaCheck.Result.PASSED)
	if last_floor or run.marker_used:
		return QuotaCheck.new(QuotaCheck.Result.LOST)
	var fronted: int = Marker.front(_config, quota, run.bankroll)
	if run.bankroll + fronted < quota:
		return QuotaCheck.new(QuotaCheck.Result.LOST)
	_borrow(fronted)
	return QuotaCheck.new(QuotaCheck.Result.MARKER, fronted)


func _open_end_shop() -> void:
	next_floor_min = _config.get_int_list("floors", "low_stakes_min")[run.floor_number]
	var services: DeckServices = DeckServices.new(
		DeckRules.from_config(_config), _deck, _kit, _pricing, run.bankroll,
		_rng.stream(GameRng.Stream.SHOP)
	)
	shop = ShopStop.new(
		_config, _pricing, run.bankroll, next_floor_min, extra_hands_bought, services
	)
	_stock(shop)
	phase = Phase.END_SHOP


## The seated session with the index of its table at the current node.
func _session_dict() -> Dictionary:
	var saved: Dictionary = session.to_dict()
	saved["table_index"] = current.tables.find(session.table)
	return saved


func _resume_session(saved: Dictionary) -> void:
	var index: int = saved["table_index"]
	session = TableSession.resume(
		_config, current.tables[index], _deck, _layer, _kit, _rng, clock, signature, saved
	)


func _restore_services(saved: Dictionary) -> DeckServices:
	return DeckServices.from_dict(
		saved, DeckRules.from_config(_config), _deck, _kit, _pricing,
		_rng.stream(GameRng.Stream.SHOP)
	)


func _stock(stop: ShopStop) -> void:
	stop.stock(_kit, ItemRules.from_config(_config), _rng.stream(GameRng.Stream.SHOP))


## Late Night bought mid-floor (§9) lengthens this floor's clock at once;
## lost to a sweep, it shortens it at once.
func _give_late_hands() -> void:
	clock.hands_left = maxi(clock.hands_left + _kit.extra_floor_hands - _late_hands, 0)
	_late_hands = _kit.extra_floor_hands


## True when leaving the current node ends the walk.
func _walk_ends() -> bool:
	return clock.is_out() or current.row == map.row_count() - 1


func _is_broke() -> bool:
	var low_min: int = _config.get_int_list("floors", "low_stakes_min")[run.floor_number - 1]
	return run.bankroll < low_min


## Below the low-stakes minimum mid-floor: the marker fronts the capped
## shortfall and play goes on. Once it's used, or on floor 5, which the
## marker never covers, the run is lost.
func _broke() -> void:
	if run.marker_used or run.floor_number == TuneSchema.FLOORS:
		_lose()
		return
	_borrow(Marker.front(_config, quota, run.bankroll))
	phase = Phase.MAP


## Stops for the security sweep when run heat crossed its threshold, there
## is something to lose, and the run goes on.
func _start_sweep(crossed: bool) -> void:
	if not crossed or phase == Phase.DONE:
		return
	_after_sweep = phase
	phase = Phase.SWEEP
	if sweep_choices().is_empty():
		phase = _after_sweep


## Has the pit boss watch as many tables as run heat calls for, drawing new
## ones from rows ahead of the player. A watched table stays watched.
func _watch() -> void:
	var watched: int = 0
	var open: Array[Table] = []
	var from_row: int = 0 if current == null else current.row + 1
	for node: MapNode in map.nodes:
		for table: Table in node.tables:
			if table.watched:
				watched += 1
			elif node.row >= from_row:
				open.append(table)
	var rng: RandomNumberGenerator = _rng.stream(GameRng.Stream.FLOOR)
	while watched < _run_heat.watched_tables(run.run_heat) and not open.is_empty():
		var table: Table = open[rng.randi_range(0, open.size() - 1)]
		table.watched = true
		open.erase(table)
		watched += 1


func _borrow(amount: int) -> void:
	run.bankroll += amount
	marker_loan += amount
	run.marker_used = true


func _lose() -> void:
	run.lost = true
	phase = Phase.DONE
