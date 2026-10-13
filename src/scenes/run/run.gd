extends Control
## The run's root scene (block U4) and the app's main scene: shows the
## screen the run is at, swapping it as the run moves on, and tells the run
## when the app goes to the background so it saves.

const TABLE: PackedScene = preload("res://src/scenes/table/table.tscn")
const SAVE_ON: Array[int] = [
	NOTIFICATION_APPLICATION_PAUSED,
	NOTIFICATION_APPLICATION_FOCUS_OUT,
	NOTIFICATION_WM_CLOSE_REQUEST,
]
const SHOT_METHODS: Array[StringName] = [&"_shot_pick", &"_shot_buy"]
const SHOT_SAVE: String = "user://shot_save.bin"
var _vm: RunVM
## The screen on show.
var _screen: Control


func _ready() -> void:
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.randomize()
	_vm = RunVM.new(TuneConfig.load_default(), seeds)
	_show()


## For scripts/shot, which drives the scene by method: starts a run on
## this seed, saved apart from the player's own.
func _shot_run(run_seed: int) -> void:
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = run_seed
	_vm = RunVM.new(TuneConfig.load_default(), seeds, SHOT_SAVE)
	_vm.start()
	_show()


## For scripts/shot: sets the run's bankroll and run heat, and redraws.
func _shot_state(bankroll: int, run_heat: int) -> void:
	_vm.run.state.bankroll = bankroll
	_vm.run.state.add_run_heat(run_heat - _vm.run.state.run_heat)
	_show()


## For scripts/shot: enters the first node on offer, with its table at
## watched (or none, at -1) under the pit boss's eye.
func _shot_enter(watched: int) -> void:
	var floor: Floor = _vm.run.floor
	floor.enter(floor.choices()[0])
	if watched >= 0:
		floor.current.tables[watched].watched = true
	_vm.step_done()
	_show()


## For scripts/shot: walks on, skipping tables, into the first back room
## of this kind (1 a shop, 2 deck services) on the way.
func _shot_back_room(kind: int) -> void:
	var floor: Floor = _vm.run.floor
	for step: int in floor.map.row_count():
		var found: bool = false
		for node: MapNode in floor.choices():
			if node.kind == kind and not found:
				floor.enter(node)
				found = true
		if found:
			break
		floor.enter(floor.choices()[0])
		floor.leave()
	_vm.step_done()
	_show()


## For scripts/shot: calls one of the screen on show's own shot methods, by
## its place in SHOT_METHODS, with one whole number.
func _shot_call(method_index: int, value: int) -> void:
	_screen.call(SHOT_METHODS[method_index], value)


## For scripts/shot: looks at the map from the node's table offers.
func _shot_view_map() -> void:
	_vm.view_map(true)
	_show()


## For scripts/shot: sits at a table of the offers on show.
func _shot_screen_sit(index: int) -> void:
	_screen.call("_sit", index)


## For scripts/shot: walks to the first node on offer and leaves it, count
## times.
func _shot_walk(count: int) -> void:
	var floor: Floor = _vm.run.floor
	for i: int in count:
		floor.enter(floor.choices()[0])
		floor.leave()
	_vm.step_done()
	_show()


## For scripts/shot: walks the rest of the map, skipping tables, to the
## quota check and what follows it.
func _shot_finish_floor() -> void:
	var floor: Floor = _vm.run.floor
	while floor.phase == Floor.Phase.MAP and not floor.choices().is_empty():
		floor.enter(floor.choices()[0])
		floor.leave()
	_vm.step_done()
	_show()


## For scripts/shot: a security sweep, with three items in the kit and
## marks of this many symbols in the deck.
func _shot_sweep(symbols: int) -> void:
	var run: Run = _vm.run
	var rules: ItemRules = ItemRules.from_config(run.config())
	for item: ItemKind.Kind in [
		ItemKind.Kind.WAX_PENCIL, ItemKind.Kind.LATE_NIGHT, ItemKind.Kind.PERMANENT_INK,
	]:
		run.kit.add_item(item, rules)
	run.kit.refill_ink()
	var cards: Array[Card] = run.game.deck.cards()
	for i: int in symbols * 4:
		run.game.deck.mark(cards[i * 2].id, i % symbols)
	run.floor.phase = Floor.Phase.SWEEP
	_show()


## For scripts/shot: sits at the first table on offer and leaves it with
## this bankroll, which calls the marker when it is under the minimum.
func _shot_broke(bankroll: int) -> void:
	var floor: Floor = _vm.run.floor
	floor.enter(floor.choices()[0])
	floor.sit(0).bankroll = bankroll
	floor.leave()
	_vm.step_done()
	_show()


## For scripts/shot: leaves the end shop for the elevator, with this much
## run heat and this many extra hands bought.
func _shot_elevator(run_heat: int, hands: int) -> void:
	for i: int in hands:
		_vm.run.floor.shop.buy_extra_hand()
	_vm.run.floor.finish()
	_vm.step_done()
	_vm.run.state.run_heat = run_heat
	_show()


## For scripts/shot: ends the run: 0 won, 1 ejected on floor 3, 2 short on
## floor 4 after a marker on floor 2.
func _shot_end(how: int) -> void:
	var run: Run = _vm.run
	var state: RunState = run.state
	var quotas: Array[int] = run.config().get_int_list("floors", "quotas")
	var last: int = [TuneSchema.FLOORS, 3, 4][how]
	for i: int in last:
		var outcome: FloorRecord.Outcome = FloorRecord.Outcome.MET
		var loan: int = 0
		if i == last - 1 and how > 0:
			outcome = [FloorRecord.Outcome.EJECTED, FloorRecord.Outcome.SHORT][how - 1]
		elif i == 1 and how == 2:
			outcome = FloorRecord.Outcome.MARKER
			loan = quotas[i] / 10
		var over: int = quotas[i] / 8 * (1 if outcome == FloorRecord.Outcome.MET else -1)
		state.records.append(FloorRecord.new(i + 1, outcome, quotas[i], quotas[i] + over, loan))
	state.bankroll = state.records[-1].bankroll
	state.floor_number = last
	state.heat_spent = 1850.0
	state.run_heat_peak = [58.0, 100.0, 74.0][how]
	state.won = how == 0
	state.lost = how != 0
	state.ejected = how == 1
	run.phase = Run.Phase.WON if how == 0 else Run.Phase.LOST
	for item: ItemKind.Kind in [ItemKind.Kind.POKER_FACE, ItemKind.Kind.SLEIGHT,
		ItemKind.Kind.HIGH_ROLLERS_NERVE, ItemKind.Kind.SHADED_LENSES]:
		run.kit.add_item(item, ItemRules.from_config(run.config()))
	_show()


## For scripts/shot: the kit (0) or the deck (1) over the map, with four
## items owned and a few cards marked.
func _shot_kit(which: int) -> void:
	var run: Run = _vm.run
	for item: ItemKind.Kind in [ItemKind.Kind.SHADED_LENSES, ItemKind.Kind.WAX_PENCIL,
		ItemKind.Kind.LATE_NIGHT, ItemKind.Kind.PERMANENT_INK]:
		run.kit.add_item(item, ItemRules.from_config(run.config()))
	var cards: Array[Card] = run.game.deck.cards()
	for i: int in 7:
		run.game.deck.mark(cards[i * 5].id, i % 3)
	_show()
	_screen.call("_on_open", which)


func _notification(what: int) -> void:
	if _vm != null and what in SAVE_ON:
		_vm.on_background()


## Puts up the screen the run is at, in place of the last one.
func _show() -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	match _vm.screen():
		RunVM.Screen.HOME:
			var home: HomeScreen = HomeScreen.new(HomeVM.new(_vm))
			home.run_opened.connect(_show)
			home.scene_wanted.connect(_on_scene)
			_screen = home
		RunVM.Screen.MAP:
			var map: MapScreen = MapScreen.new(MapVM.new(_vm), KitVM.new(_vm))
			map.moved.connect(_show.call_deferred)
			_screen = map
		RunVM.Screen.OFFERS:
			var offers: OffersScreen = OffersScreen.new(OffersVM.new(_vm))
			offers.moved.connect(_show.call_deferred)
			_screen = offers
		RunVM.Screen.SHOP:
			var shop: ShopScreen = ShopScreen.new(ShopVM.new(_vm))
			shop.moved.connect(_show.call_deferred)
			_screen = shop
		RunVM.Screen.DECK_SERVICES:
			var services: ServicesScreen = ServicesScreen.new(
				ServicesVM.new(_vm, _vm.run.floor.services)
			)
			services.moved.connect(_show.call_deferred)
			_screen = services
		RunVM.Screen.SWEEP:
			var sweep: SweepScreen = SweepScreen.new(SweepVM.new(_vm))
			sweep.moved.connect(_show.call_deferred)
			_screen = sweep
		RunVM.Screen.ELEVATOR:
			var elevator: ElevatorScreen = ElevatorScreen.new(ElevatorVM.new(_vm))
			elevator.moved.connect(_show.call_deferred)
			_screen = elevator
		RunVM.Screen.RUN_END:
			var run_end: RunEndScreen = RunEndScreen.new(RunEndVM.new(_vm))
			run_end.moved.connect(_show.call_deferred)
			_screen = run_end
		RunVM.Screen.MARKER:
			var marker: MarkerScreen = MarkerScreen.new(MarkerVM.new(_vm))
			marker.moved.connect(_show.call_deferred)
			_screen = marker
		RunVM.Screen.END_SHOP:
			var end_shop: EndShopScreen = EndShopScreen.new(EndShopVM.new(_vm))
			end_shop.moved.connect(_show.call_deferred)
			_screen = end_shop
		RunVM.Screen.TABLE:
			var table: TableScreen = TABLE.instantiate()
			table.host(RunTableVM.new(_vm))
			table.left.connect(_show.call_deferred)
			_screen = table
	add_child(_screen)


func _on_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
