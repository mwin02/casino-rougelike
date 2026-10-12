class_name TableHud
extends Control
## The table's standing panels, to the design canvas: which table this is
## (top left), the bankroll (top right) and the heat meter (left). The
## quota bar and the hand clock join them with the floor screens (U4).

const GUTTER: float = 44.0

var _subtitle: Label
var _title: Label
var _clock: Label
var _bankroll: Label
var _bankroll_panel: PanelContainer
var _meter: HeatMeter


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var table: VBoxContainer = _panel(Vector2(GUTTER, 12.0), -1.5)
	_subtitle = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_title = UiKit.label("", Fonts.Face.TITLE, 19, Palette.CREAM)
	_clock = UiKit.label("", Fonts.Face.BODY_HEAVY, 12, Palette.CREAM)
	for label: Label in [_subtitle, _title, _clock]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		table.add_child(label)

	var money: VBoxContainer = _panel(Vector2.ZERO, 1.0)
	_bankroll_panel = money.get_parent()
	_bankroll_panel.custom_minimum_size.x = 188.0
	var row: HBoxContainer = HBoxContainer.new()
	money.add_child(row)
	var caption: Label = UiKit.label("BANKROLL", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(caption)
	_bankroll = UiKit.label("", Fonts.Face.NUMBER, 21, Palette.CREAM)
	row.add_child(_bankroll)

	_meter = HeatMeter.new()
	_meter.position = Vector2(GUTTER, 104.0)
	add_child(_meter)


func refresh(vm: TableScreenVM) -> void:
	_subtitle.text = vm.subtitle()
	_title.text = vm.title()
	_clock.text = vm.clock_text()
	_clock.visible = not _clock.text.is_empty()
	_bankroll.text = vm.bankroll_text()
	_bankroll_panel.reset_size()
	_bankroll_panel.position = Vector2(size.x - GUTTER - _bankroll_panel.size.x, 12.0)
	_meter.show_meter(vm.meter())


## A dark panel set a touch askew, as if pinned up; returns its column.
func _panel(at: Vector2, tilt: float) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.rotation_degrees = tilt
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	panel.add_child(column)
	return column
