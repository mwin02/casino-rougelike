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
## Screens with nothing drawn yet, by name.
const UNBUILT: Dictionary[RunVM.Screen, String] = {
	RunVM.Screen.MAP: "Floor map",
	RunVM.Screen.OFFERS: "Table offers",
	RunVM.Screen.SHOP: "Shop",
	RunVM.Screen.DECK_SERVICES: "Deck services",
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
