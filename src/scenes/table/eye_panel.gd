class_name EyePanel
extends PanelContainer
## The eye in the sky's panel, after the design canvas: it walks an action
## through the ActionPicker's steps. First the action, under Read or Rig,
## each with its heat; then the card, here or by tapping it on the table;
## then what to do to it. Above those sit what the actions found so far
## and, for a card changed this hand, the ways to keep the change.

signal changed

const WIDTH: float = 252.0
const KEEPS: int = 3

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
	_title.text = "Eye in the sky" if choosing else HeatText.action_name(picker.action())
	_prompt.text = picker.prompt_text().to_upper()
	UiKit.clear(_body)
	_add_results(picker)
	_add_keeps(picker)
	if choosing:
		_add_actions(picker)
	else:
		_add_choices(picker)
		_body.add_child(_plain("Back", picker.can_go_back(), _back))
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


## Tape, Seal and Ink for each card changed this hand, three to a row.
func _add_keeps(picker: ActionPicker) -> void:
	var keeps: Array[Choice] = picker.keep_choices()
	for start: int in range(0, keeps.size(), KEEPS):
		var card: String = keeps[start].label.get_slice(" · ", 1)
		_body.add_child(_caption("KEEP THE CHANGE · " + card.to_upper()))
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		_body.add_child(line)
		for keep: Choice in keeps.slice(start, start + KEEPS):
			var text: String = "%s %s" % [keep.label.get_slice(" · ", 0), keep.detail]
			var button: Button = UiKit.option(text, false, 12)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 36.0
			button.disabled = not keep.enabled
			button.pressed.connect(_keep.bind(keep.id))
			line.add_child(button)


## What the actions found, newest first, and the cards a look ahead showed.
func _add_results(picker: ActionPicker) -> void:
	if picker.info_lines.is_empty():
		return
	_body.add_child(_caption("ON CAMERA"))
	if not picker.shown_cards.is_empty():
		var cards: HBoxContainer = HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		_body.add_child(cards)
		for card: Card in picker.shown_cards:
			var face: CardFace = CardFace.new()
			cards.add_child(face)
			face.show_card(CardView.new(card, false, false), 34.0)
	var lines: PackedStringArray = picker.info_lines.duplicate()
	lines.reverse()
	for text: String in lines.slice(0, 2):
		var told: Label = UiKit.label(text, Fonts.Face.BODY_HEAVY, 11, Palette.TEAL)
		told.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		told.custom_minimum_size.x = WIDTH - 24.0
		_body.add_child(told)


## A choice as a wide button: its name on the left, its heat on the right.
func _row(choice: Choice, height: float) -> Button:
	var text: String = choice.label
	if not choice.detail.is_empty():
		text = "%s   %s heat" % [choice.label, choice.detail]
	var button: Button = UiKit.option(text, choice.selected, 14)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = height
	button.disabled = not choice.enabled
	button.pressed.connect(_pick.bind(choice.id))
	return button


func _plain(text: String, enabled: bool, on_press: Callable) -> Button:
	var button: Button = UiKit.option(text, false, 12)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.disabled = not enabled
	button.pressed.connect(on_press)
	return button


func _caption(text: String) -> Label:
	var caption: Label = UiKit.label(text, Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return caption


func _show_tab(rig: bool) -> void:
	_rigging = rig
	changed.emit()


func _pick(id: int) -> void:
	_vm.picker().pick(id)
	changed.emit()


func _keep(id: int) -> void:
	_vm.picker().keep(id)
	changed.emit()


func _back() -> void:
	_vm.picker().back()
	changed.emit()
