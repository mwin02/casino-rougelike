class_name MarkerScreen
extends Control
## The marker's notice (block U4), to "The marker" artboard: the house's
## slip on the left, with the loan, its interest and what joins the next
## quota; the bankroll and that quota before and after on the right, and the
## warning that the marker is spent. Draws a MarkerVM.

## The notice has been read.
signal moved

const SLIP: Rect2 = Rect2(60.0, 30.0, 400.0, 0.0)
const SIDE: Rect2 = Rect2(506.0, 22.0, 294.0, 0.0)
## Ink on the cream slip.
const INK: Color = Palette.PANEL
const FADED: Color = Color(Palette.PANEL, 0.68)

var _vm: MarkerVM
var _frame: DesignFrame


func _init(vm: MarkerVM) -> void:
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
	dim.color = Color(Palette.WELL, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, _frame.get_index())
	_build_slip()
	_build_side()


## The house's slip of cream paper, taped down at a tilt.
func _build_slip() -> void:
	var paper: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Palette.CREAM, 14)
	box.set_content_margin_all(6)
	box.border_color = Palette.CREAM_EDGE
	box.border_width_bottom = 3
	box.shadow_color = UiKit.SHADOW
	box.shadow_size = 12
	paper.add_theme_stylebox_override("panel", box)
	paper.position = SLIP.position
	paper.custom_minimum_size.x = SLIP.size.x
	paper.rotation_degrees = -2.0
	_frame.add_child(paper)
	_frame.add_child(UiKit.tape(Vector2(230.0, 18.0), Vector2(60.0, 17.0), 3.0))
	var inner: PanelContainer = PanelContainer.new()
	var edge: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 10)
	edge.draw_center = false
	edge.set_border_width_all(1)
	edge.border_color = Palette.GOLD
	edge.content_margin_left = 18
	edge.content_margin_right = 18
	edge.content_margin_top = 10
	edge.content_margin_bottom = 10
	inner.add_theme_stylebox_override("panel", edge)
	paper.add_child(inner)
	var column: VBoxContainer = _stack(6)
	inner.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	column.add_child(head)
	head.add_child(Icons.rect("icons/marker", 16.0, FADED))
	var house: Label = _left(UiKit.label("THE HOUSE · MARKER", Fonts.Face.LABEL, 12, FADED))
	house.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(house)
	head.add_child(UiKit.chip(MarkerVM.ONCE, INK, Palette.CREAM))
	column.add_child(_wrapped(_vm.title(), Fonts.Face.TITLE, 24, INK))
	column.add_child(_wrapped(_vm.reason(), Fonts.Face.BODY_HEAVY, 12, FADED))
	var rule: ColorRect = ColorRect.new()
	rule.color = INK
	rule.custom_minimum_size.y = 1.5
	column.add_child(rule)
	column.add_child(_line("Fronted", _vm.fronted_text(), INK))
	column.add_child(_line(_vm.interest_label(), _vm.interest_text(), INK))
	var owed: PanelContainer = PanelContainer.new()
	var ground: StyleBoxFlat = UiKit.filled(Palette.TAPE, 9)
	ground.content_margin_left = 8
	ground.content_margin_right = 8
	ground.content_margin_top = 2
	ground.content_margin_bottom = 3
	owed.add_theme_stylebox_override("panel", ground)
	owed.add_child(_line(_vm.owed_label(), _vm.owed_text(), Palette.ALERT_EDGE, 21))
	column.add_child(owed)
	column.add_child(_left(UiKit.label(_vm.footer(), Fonts.Face.LABEL, 11, FADED)))
	var stamp: Label = UiKit.label(MarkerVM.STAMP, Fonts.Face.LABEL, 15, Palette.ALERT_EDGE)
	var ring: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 6)
	ring.draw_center = false
	ring.set_border_width_all(2)
	ring.border_color = Palette.ALERT_EDGE
	ring.content_margin_left = 10
	ring.content_margin_right = 10
	ring.content_margin_top = 1
	ring.content_margin_bottom = 2
	stamp.add_theme_stylebox_override("normal", ring)
	stamp.position = Vector2(SLIP.end.x - 112.0, SLIP.position.y + 203.0)
	stamp.rotation_degrees = 7.0
	stamp.modulate.a = 0.8
	_frame.add_child(stamp)


## "Fronted ........ $70,000" on the slip.
func _line(caption: String, value: String, ink: Color, size: int = 18) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var name: Label = _left(UiKit.label(caption, Fonts.Face.BODY_HEAVY, 13, INK))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(UiKit.label(value, Fonts.Face.NUMBER, size, ink))
	return row


## The bankroll, the next quota, the warning and the way back.
func _build_side() -> void:
	var column: VBoxContainer = _stack(9)
	column.position = SIDE.position
	column.custom_minimum_size.x = SIDE.size.x
	_frame.add_child(column)
	_frame.add_child(UiKit.tape(SIDE.position + Vector2(120.0, -8.0), Vector2(54.0, 15.0), -3.0))
	column.add_child(_change(
		"BANKROLL", _vm.fronted_gain_text(), Palette.WIN,
		_vm.bankroll_before_text(), _vm.bankroll_after_text(), 34
	))
	var quota: PanelContainer = _change(
		_vm.quota_label(), _vm.owed_text(), Palette.RUN_HEAT,
		_vm.quota_before_text(), _vm.quota_after_text(), 26
	)
	quota.get_child(0).add_child(_wrapped(_vm.quota_note(), Fonts.Face.BODY, 11, Palette.MUTED))
	column.add_child(quota)
	var warning: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.border_color = Color(Palette.RUN_HEAT, 0.6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 8
	warning.add_theme_stylebox_override("panel", box)
	column.add_child(warning)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	warning.add_child(row)
	row.add_child(Icons.rect("icons/siren", 20.0, Palette.RUN_HEAT))
	var words: VBoxContainer = _stack(-2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(_left(UiKit.label(MarkerVM.USED, Fonts.Face.BODY_HEAVY, 13, Palette.CREAM)))
	words.add_child(_wrapped(MarkerVM.WARNING, Fonts.Face.BODY, 11, Palette.MUTED))
	var done: Button = UiKit.button(MarkerVM.DONE, true, 17)
	done.icon = Icons.of("icons/arrow")
	done.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	done.add_theme_constant_override("icon_max_width", 18)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		done.add_theme_color_override(colour, Palette.PANEL)
	done.custom_minimum_size.y = 48.0
	done.position = Vector2(SIDE.end.x - 210.0, 326.0)
	done.custom_minimum_size.x = 210.0
	done.pressed.connect(_on_done)
	_frame.add_child(done)


## A dark panel showing an amount before and after, and the change.
func _change(
	caption: String, gain: String, gain_ink: Color, before: String, after: String, size: int
) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var column: VBoxContainer = UiKit.panel_column(panel, 10, 0)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var name: Label = _left(UiKit.label(caption, Fonts.Face.LABEL, 11, Palette.MUTED))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiKit.label(gain, Fonts.Face.NUMBER, 13, gain_ink))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	row.add_child(UiKit.label(before, Fonts.Face.NUMBER, roundi(size * 0.7), Palette.MUTED))
	row.add_child(Icons.rect("icons/arrow", 20.0, Palette.GOLD))
	row.add_child(UiKit.label(after, Fonts.Face.NUMBER, size, Palette.CREAM))
	return panel


func _wrapped(text: String, face: Fonts.Face, size: int, ink: Color) -> Label:
	var label: Label = _left(UiKit.label(text, face, size, ink))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", -2)
	return label


func _stack(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	return column


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _on_done() -> void:
	_vm.done()
	moved.emit()
