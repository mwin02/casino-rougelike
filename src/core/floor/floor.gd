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

enum Phase {
	## Choosing the next node.
	MAP,
	## At a table node, seated or not.
	AT_TABLE,
	## At a shop or deck services.
	AT_STOP,
	## The walk is over.
	QUOTA_CHECK,
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
## The next floor's low-stakes minimum: the end shop's reserve.
var next_floor_min: int = 0

var _config: TuneConfig
var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _rng: GameRng
var _pricing: ShopPricing


## map null rolls the floor's map from the run's FLOOR stream.
func _init(
	config: TuneConfig,
	p_run: RunState,
	deck: Deck,
	layer: ManipulationLayer,
	kit: ActionKit,
	rng: GameRng,
	p_map: FloorMap = null
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
	clock = FloorClock.from_config(
		config, run.extra_hands + run.carried_hands + kit.extra_floor_hands
	)
	kit.refill_ink()
	quota = config.get_int_list("floors", "quotas")[run.floor_number - 1] + run.quota_carry
	_pricing = ShopPricing.from_config(config, run.floor_number)


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
		HeatFloor.of(_deck, _kit, DeckRules.from_config(_config)), clock
	)
	return session


## Leaves the current node, banking its money and run heat, and moves on.
## Refused mid-hand and away from a node.
func leave() -> bool:
	match phase:
		Phase.AT_TABLE:
			if session != null:
				var end: SessionEnd = session.stand_up()
				if end == null:
					return false
				run.bankroll = end.bankroll
				run.add_run_heat(end.run_heat_added)
				session = null
				if not _walk_ends() and _is_broke():
					_broke()
					return true
		Phase.AT_STOP:
			if shop != null:
				run.bankroll = shop.bankroll()
				extra_hands_bought = shop.extra_hands
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
	phase = Phase.END_SHOP


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


func _borrow(amount: int) -> void:
	run.bankroll += amount
	marker_loan += amount
	run.marker_used = true


func _lose() -> void:
	run.lost = true
	phase = Phase.DONE
