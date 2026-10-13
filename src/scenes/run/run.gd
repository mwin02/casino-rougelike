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
## Screens with nothing drawn yet, by name.
const UNBUILT: Dictionary[RunVM.Screen, String] = {
	RunVM.Screen.SWEEP: "Security sweep",
	RunVM.Screen.END_SHOP: "End shop",
	RunVM.Screen.ELEVATOR: "Elevator",
	RunVM.Screen.RUN_END: "Run end",
}

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
			var map: MapScreen = MapScreen.new(MapVM.new(_vm))
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
		RunVM.Screen.TABLE:
			var table: TableScreen = TABLE.instantiate()
			table.host(RunTableVM.new(_vm))
			table.left.connect(_show.call_deferred)
			_screen = table
		_:
			_screen = _unbuilt(UNBUILT[_vm.screen()])
	add_child(_screen)


## A stand-in for a screen a later change draws: its name and a way home.
func _unbuilt(title: String) -> Control:
	var stand_in: Control = Control.new()
	stand_in.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame: DesignFrame = DesignFrame.new()
	stand_in.add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(DesignFrame.GUTTER, 24.0)
	frame.add_child(column)
	column.add_child(UiKit.label(title, Fonts.Face.TITLE, 22, Palette.CREAM))
	var home: Button = UiKit.button("Home")
	home.pressed.connect(_on_home)
	column.add_child(home)
	return stand_in


func _on_home() -> void:
	_vm.go_home()
	_show()


func _on_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
