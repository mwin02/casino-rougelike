class_name SweepScreen
extends Control
## The security sweep (block U4), to the "Security sweep" artboard: run
## heat at the top, the kit's items on the left and the marked symbols on
## the right, each a button, and the pick's cost beside Confirm along the
## bottom. Draws a SweepVM and forwards presses.

## The run has moved to another screen.
signal moved

const ITEMS: Rect2 = Rect2(44.0, 98.0, 432.0, 222.0)
const SYMBOLS: Rect2 = Rect2(488.0, 98.0, 312.0, 222.0)
const HEAT_WIDTH: float = 318.0
const MARK_NAMES: Array[String] = ["Pit boss", "Sweep", "Ejected"]
## Past this many symbols they go two across, one card each.
const ROOMY_SYMBOLS: int = 3

var _vm: SweepVM
var _frame: DesignFrame
var _items: GridContainer
var _symbols: GridContainer
var _note: Label
var _confirm: Button


func _init(vm: SweepVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new(218.0, false))
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(Palette.WELL, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, _frame.get_index())
	_build_title()
	_build_heat()
	_items = _build_list(ITEMS, "Lose an item", _vm.slots_text(), 3)
	_symbols = _build_list(SYMBOLS, "Or clear a symbol", "EVERY MARK GOES", 1)
	_frame.add_child(UiKit.tape(Vector2(SYMBOLS.end.x - 70.0, 90.0), Vector2(44.0, 15.0), 3.0))
	_build_foot()
	_refresh()


func _build_title() -> void:
	var panel: PanelContainer = _slip(Vector2(ITEMS.position.x, 12.0), -1.5)
	var column: VBoxContainer = _stack(-4)
	panel.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	column.add_child(head)
	head.add_child(Icons.rect("icons/siren", 12.0, Palette.ALERT))
	head.add_child(UiKit.label("SECURITY SWEEP", Fonts.Face.LABEL, 11, Palette.ALERT))
	column.add_child(_left(UiKit.label("Choose what to lose", Fonts.Face.TITLE, 20, Palette.CREAM)))
	column.add_child(_left(UiKit.label(SweepVM.HINT, Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)))


## Run heat against its three marks.
func _build_heat() -> void:
	var hud: FloorHudVM = _vm.hud()
	var marks: Array[int] = hud.heat_marks()
	var panel: PanelContainer = _slip(Vector2(SYMBOLS.end.x - HEAT_WIDTH, 12.0), 1.0)
	panel.custom_minimum_size.x = HEAT_WIDTH
	_frame.add_child(UiKit.tape(Vector2(panel.position.x + 132.0, 5.0), Vector2(46.0, 14.0), -4.0))
	var column: VBoxContainer = _stack(1)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = _left(UiKit.label("RUN HEAT", Fonts.Face.LABEL, 11, Palette.MUTED))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	top.add_child(UiKit.label(hud.run_heat_text(), Fonts.Face.NUMBER, 22, Palette.CREAM))
	top.add_child(UiKit.label(" / %d" % marks[-1], Fonts.Face.NUMBER, 13, Palette.MUTED))
	var bar: ShareBar = ShareBar.new(Vector2(0.0, 12.0), Palette.RUN_HEAT)
	bar.show_share(hud.run_heat_share())
	column.add_child(bar)
	var row: Control = Control.new()
	row.custom_minimum_size.y = 24.0
	column.add_child(row)
	var shares: Array[float] = hud.heat_mark_shares()
	var reached: Array[bool] = hud.heat_marks_reached()
	var width: float = HEAT_WIDTH - 28.0
	for i: int in marks.size():
		var mark: Label = UiKit.label(
			"%d\n%s" % [marks[i], MARK_NAMES[i]], Fonts.Face.LABEL, 11,
			Palette.RUN_HEAT if reached[i] else Palette.MUTED
		)
		mark.add_theme_constant_override("line_spacing", -4)
		mark.size = Vector2(60.0, 24.0)
		mark.position.x = minf(width * shares[i] - 30.0, width - 60.0)
		if i == marks.size() - 1:
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(mark)


## A titled panel holding a grid of things to lose; returns the grid.
func _build_list(rect: Rect2, title: String, caption: String, columns: int) -> GridContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	_frame.add_child(panel)
	var column: VBoxContainer = UiKit.panel_column(panel, 12, 8)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var name: Label = _left(UiKit.label(title, Fonts.Face.TITLE, 16, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiKit.label(caption, Fonts.Face.LABEL, 11, Palette.MUTED))
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	return grid


func _build_foot() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(ITEMS.position.x, 330.0)
	row.custom_minimum_size = Vector2(SYMBOLS.end.x - ITEMS.position.x, 48.0)
	row.size = row.custom_minimum_size
	row.add_theme_constant_override("separation", 16)
	_frame.add_child(row)
	var pill: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(24)
	box.content_margin_left = 16
	box.content_margin_right = 16
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pill)
	_note = _left(UiKit.label("", Fonts.Face.BODY_HEAVY, 12, Palette.CREAM))
	_note.clip_text = true
	pill.add_child(_note)
	_confirm = UiKit.button("", true, 16)
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)


func _refresh() -> void:
	UiKit.clear(_items)
	for row: SweepRow in _vm.items():
		_items.add_child(_item(row))
	for i: int in _vm.empty_slots():
		_items.add_child(_empty_slot())
	UiKit.clear(_symbols)
	var symbols: Array[SweepRow] = _vm.symbols()
	_symbols.columns = 1 if symbols.size() <= ROOMY_SYMBOLS else 2
	for row: SweepRow in symbols:
		_symbols.add_child(_symbol(row, symbols.size() <= ROOMY_SYMBOLS))
	if symbols.is_empty():
		var none: Label = UiKit.label("No marked cards.", Fonts.Face.BODY, 12, Palette.MUTED)
		none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_symbols.add_child(none)
	_note.text = _vm.note()
	_confirm.text = _vm.confirm_text()
	_confirm.disabled = not _vm.can_confirm()


## An item to lose: its name, and its effect or what else losing it costs.
func _item(row: SweepRow) -> Button:
	var button: Button = _choice(row)
	var words: VBoxContainer = _stack(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	_fill(button, words)
	words.add_child(_left(UiKit.label(row.name, Fonts.Face.BUTTON, 14, Palette.CREAM)))
	var costly: bool = not row.warning.is_empty()
	var detail: Label = _left(UiKit.label(
		row.warning if costly else row.detail, Fonts.Face.BODY_HEAVY, 10,
		Palette.RUN_HEAT if costly else Palette.MUTED
	))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 3
	detail.add_theme_constant_override("line_spacing", -3)
	words.add_child(detail)
	return button


func _empty_slot() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 10)
	box.draw_center = false
	box.set_border_width_all(1)
	box.border_color = Palette.DIM_EDGE
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(UiKit.label("EMPTY SLOT", Fonts.Face.LABEL, 11, Palette.OUTLINE))
	return panel


## A symbol to clear: some of its cards fanned, its name and its count.
func _symbol(row: SweepRow, roomy: bool) -> Button:
	var button: Button = _choice(row)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12 if roomy else 8)
	_fill(button, line)
	var shown: int = row.cards.size() if roomy else 1
	var fan: Control = Control.new()
	var card_width: float = 36.0 if roomy else 26.0
	fan.custom_minimum_size = Vector2(card_width + 2.0 + 22.0 * (shown - 1), card_width * 1.5)
	fan.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(fan)
	for i: int in shown:
		var face: CardFace = CardFace.new()
		face.draws_mark = true
		face.show_card(row.cards[i], card_width)
		face.position = Vector2(22.0 * i, 2.0)
		face.rotation_degrees = 8.0 * (i - (shown - 1) / 2.0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan.add_child(face)
	var words: VBoxContainer = _stack(-3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	words.add_child(_left(UiKit.label(row.name, Fonts.Face.BUTTON, 15, Palette.CREAM)))
	words.add_child(
		_left(UiKit.label(row.detail, Fonts.Face.NUMBER, 14 if roomy else 12, Palette.MUTED))
	)
	if row.picked:
		line.add_child(Icons.rect("icons/check", 20.0, Palette.GOLD))
	return button


## A wide button for one thing to lose, gold-edged when picked.
func _choice(row: SweepRow) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = UiKit.filled(Palette.BUTTON if row.picked else Palette.INSET, 10)
	box.set_border_width_all(2 if row.picked else 1)
	box.border_color = Palette.GOLD if row.picked else Palette.DIM_EDGE
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(_on_pick.bind(row.choice))
	return button


## Lays content over a button, inside its padding.
func _fill(button: Button, content: Control) -> void:
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_right = -8.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)


## A dark slip of paper at a tilt.
func _slip(at: Vector2, tilt: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 5
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.rotation_degrees = tilt
	_frame.add_child(panel)
	return panel


func _stack(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	return column


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## For scripts/shot: picks the symbol at this place.
func _shot_pick(index: int) -> void:
	_on_pick(_vm.symbols()[index].choice)


func _on_pick(choice: SweepChoice) -> void:
	_vm.pick(choice)
	_refresh()


func _on_confirm() -> void:
	_vm.confirm()
	moved.emit()
