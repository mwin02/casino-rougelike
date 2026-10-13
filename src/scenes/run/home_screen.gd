class_name HomeScreen
extends Control
## The home screen, plain for now (block U4): continue or abandon the saved
## run, start a new one at a difficulty, or open a debug screen. The designed
## start screen replaces it later.

## A run was started or continued.
signal run_opened
signal scene_wanted(path: String)

const WIDTH: float = 420.0
const DEBUG_SCENES: Dictionary[String, String] = {
	"Free table": "res://src/scenes/table/table.tscn",
	"Debug table": "res://src/scenes/table_debug.tscn",
	"Gallery": "res://src/scenes/ui/gallery.tscn",
}

var _vm: HomeVM
var _continue: Button
var _levels: HBoxContainer
var _start: Button
var _note: Label
var _abandon: Button


func _init(vm: HomeVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	var frame: DesignFrame = DesignFrame.new()
	add_child(frame)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	panel.position = Vector2((DesignFrame.SIZE.x - WIDTH) / 2.0, 24.0)
	frame.add_child(panel)
	var column: VBoxContainer = UiKit.panel_column(panel, 14, 8)
	column.add_child(UiKit.label("Rob the Casino", Fonts.Face.TITLE, 24, Palette.CREAM))
	_continue = UiKit.button("", true, 17)
	_continue.pressed.connect(_on_continue)
	column.add_child(_continue)
	column.add_child(_caption("NEW RUN"))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	column.add_child(line)
	_levels = HBoxContainer.new()
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels.add_theme_constant_override("separation", 5)
	line.add_child(_levels)
	_start = UiKit.button("Start run", true, 15)
	_start.pressed.connect(_on_start)
	line.add_child(_start)
	_note = UiKit.label("", Fonts.Face.BODY, 11, Palette.MUTED)
	column.add_child(_note)
	_abandon = UiKit.button("", false, 13)
	_abandon.pressed.connect(_on_abandon)
	column.add_child(_abandon)
	column.add_child(_caption("DEBUG"))
	var debug: HBoxContainer = HBoxContainer.new()
	debug.add_theme_constant_override("separation", 8)
	column.add_child(debug)
	for title: String in DEBUG_SCENES:
		var button: Button = UiKit.button(title, false, 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(scene_wanted.emit.bind(DEBUG_SCENES[title]))
		debug.add_child(button)
	_refresh()


func _caption(text: String) -> Label:
	var made: Label = UiKit.label(text, Fonts.Face.LABEL, 11, Palette.MUTED)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return made


func _refresh() -> void:
	_continue.text = _vm.continue_label()
	_continue.disabled = not _vm.can_continue()
	UiKit.clear(_levels)
	for choice: Choice in _vm.difficulty_choices():
		var option: Button = UiKit.option(choice.label, choice.selected)
		option.pressed.connect(_on_level.bind(choice.id))
		_levels.add_child(option)
	_start.disabled = not _vm.can_start()
	_note.text = _vm.start_note()
	_note.visible = not _note.text.is_empty()
	_abandon.text = _vm.abandon_label()
	_abandon.visible = _vm.can_abandon()


func _on_continue() -> void:
	_vm.continue_run()
	run_opened.emit()


func _on_level(level: int) -> void:
	_vm.choose_difficulty(level)
	_refresh()


func _on_start() -> void:
	_vm.start()
	run_opened.emit()


func _on_abandon() -> void:
	_vm.press_abandon()
	_refresh()
