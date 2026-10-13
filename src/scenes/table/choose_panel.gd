class_name ChoosePanel
extends PanelContainer
## Choosing a table at the free table: the game, stakes, floor, house rule
## and kit, then Sit down. It also says how the last session ended, and
## leads home and to the debug table.

signal changed
signal sat_down
signal debug_wanted
signal home_wanted

const WIDTH: float = 560.0
const END_TEXT: Dictionary[SessionEnd.Reason, String] = {
	SessionEnd.Reason.STOOD_UP: "You stood up",
	SessionEnd.Reason.BACKED_OFF: "You were backed off",
	SessionEnd.Reason.BROKE: "You went broke",
}

var _rows: Array[HFlowContainer] = []
var _ended: Label
var _sit: Button


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel()
	box.set_content_margin_all(12)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title: Label = UiKit.label("Choose a table", Fonts.Face.TITLE, 17, Palette.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)
	for caption: String in ["GAME", "STAKES", "FLOOR", "HOUSE RULE", "KIT"]:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		column.add_child(line)
		var name: Label = UiKit.label(caption, Fonts.Face.LABEL, 11, Palette.MUTED)
		name.custom_minimum_size.x = 70.0
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.add_child(name)
		var row: HFlowContainer = HFlowContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("h_separation", 5)
		row.add_theme_constant_override("v_separation", 5)
		line.add_child(row)
		_rows.append(row)
	_ended = UiKit.label("", Fonts.Face.BODY, 12, Palette.SOFT)
	_ended.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_ended)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	column.add_child(foot)
	var home: Button = UiKit.button("Home", false, 13)
	home.pressed.connect(home_wanted.emit)
	foot.add_child(home)
	var debug: Button = UiKit.button("Debug table", false, 13)
	debug.pressed.connect(debug_wanted.emit)
	foot.add_child(debug)
	_sit = UiKit.button("Sit down", true)
	_sit.pressed.connect(sat_down.emit)
	foot.add_child(_sit)


func refresh(vm: TableScreenVM) -> void:
	var setup: TableSetupVM = vm.setup
	_fill(_rows[0], setup.game_choices(), setup.choose_game)
	_fill(_rows[1], setup.stakes_choices(), setup.choose_stakes)
	_fill(_rows[2], setup.floor_choices(), setup.choose_floor)
	_fill(_rows[3], setup.house_rule_choices(), setup.choose_house_rule)
	_fill(_rows[4], setup.kit_choices(), setup.choose_kit)
	_sit.disabled = not vm.can_sit_down()
	var ended: SessionEnd = vm.ended()
	_ended.visible = ended != null
	if ended != null:
		_ended.text = "%s: %s over %d hands." % [
			END_TEXT[ended.reason], MoneyFormat.format_signed(ended.net), ended.hands_played
		]


func _fill(row: HFlowContainer, choices: Array[Choice], on_press: Callable) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for choice: Choice in choices:
		var button: Button = UiKit.option(choice.label, choice.selected)
		button.disabled = not choice.enabled
		button.pressed.connect(_pressed.bind(on_press, choice.id))
		row.add_child(button)


func _pressed(on_press: Callable, id: int) -> void:
	on_press.call(id)
	changed.emit()
