class_name TricksPanel
extends PanelContainer
## The Tricks screen's right panel: it walks an action through the
## ActionPicker's steps. First the action, under Read or Rig, each with its
## heat; then the card, by tapping it on the table; then what to do to it.
## What the actions did is in TrickHistoryPanel, on the left.

signal changed

const WIDTH: float = 252.0

var _vm: TableScreenVM
var _rigging: bool = false
var _title: Label
var _prompt: Label
var _body: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = UiKit.panel_column(self, 10, 6)
	_title = UiKit.label("", Fonts.Face.TITLE, 16, Palette.CREAM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_title)
	_prompt = UiKit.label("", Fonts.Face.CAMERA, 10, Palette.TEAL)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size.x = WIDTH - 20.0
	column.add_child(_prompt)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 5)
	_scroll.add_child(_body)


## max_height is the room the panel has; past it, its body scrolls.
func refresh(vm: TableScreenVM, max_height: float) -> void:
	_vm = vm
	var picker: ActionPicker = vm.picker()
	if picker == null or not vm.in_hand():
		return
	var choosing: bool = picker.step() == ActionPicker.Step.ACTION
	_title.text = "Tricks" if choosing else HeatText.action_name(picker.action())
	_prompt.text = picker.prompt_text().to_upper()
	UiKit.clear(_body)
	if choosing:
		_add_actions(picker)
	else:
		# A card is picked by tapping it on the table.
		if picker.step() not in [ActionPicker.Step.CARD, ActionPicker.Step.OTHER_CARD]:
			_add_choices(picker)
		_body.add_child(_foot(picker))
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, max_height - 70.0)
	reset_size()


## Read and Rig, then the four actions of the one chosen.
func _add_actions(picker: ActionPicker) -> void:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)
	for rig: bool in [false, true]:
		var tab: Button = UiKit.option("Rig" if rig else "Read", rig == _rigging, 13)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_tab.bind(rig))
		tabs.add_child(tab)
	var family: Array[ActionKind.Kind] = ActionKind.MANIPULATION if _rigging else ActionKind.KNOWLEDGE
	for choice: Choice in picker.choices():
		if (choice.id as ActionKind.Kind) in family:
			_body.add_child(_row(choice, 42.0))


## The current step's choices: a long list as a grid, the rest as rows.
func _add_choices(picker: ActionPicker) -> void:
	var choices: Array[Choice] = picker.choices()
	if choices.size() <= 6:
		for choice: Choice in choices:
			_body.add_child(_row(choice, 40.0))
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(grid)
	for choice: Choice in choices:
		var cell: Button = UiKit.option(choice.label, false, 14)
		cell.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
		cell.custom_minimum_size = Vector2(0.0, 36.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_pick.bind(choice.id))
		grid.add_child(cell)


## A choice as a wide button: its name on the left, its heat on the right.
func _row(choice: Choice, height: float) -> Button:
	var text: String = choice.label
	if not choice.detail.is_empty():
		text = "%s   %s heat" % [choice.label, choice.detail]
	var button: Button = UiKit.option(text, choice.selected, 14)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = height
	button.disabled = not choice.enabled
	# A drag that starts on a button still scrolls the list.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_pick.bind(choice.id))
	return button


## Back, and beside it in gold Ask, while questions are being ticked.
func _foot(picker: ActionPicker) -> HBoxContainer:
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	var back: Button = UiKit.option("Back", false, 13)
	back.custom_minimum_size.y = 38.0
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.disabled = not picker.can_go_back()
	back.pressed.connect(_back)
	foot.add_child(back)
	if picker.asks_many():
		var ask: Button = UiKit.option("Ask", true, 13)
		ask.custom_minimum_size.y = 38.0
		ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ask.disabled = not picker.can_ask()
		ask.pressed.connect(_pick.bind(ActionPicker.ASK))
		foot.add_child(ask)
	return foot


func _show_tab(rig: bool) -> void:
	_rigging = rig
	changed.emit()


func _pick(id: int) -> void:
	_vm.picker().pick(id)
	changed.emit()


func _back() -> void:
	_vm.picker().back()
	changed.emit()
