class_name ElevatorScreen
extends Control
## The elevator (block U4), to the "Elevator: choose the next floor"
## artboard: the bankroll carried in against the next quota, run heat with
## what the ride sheds, and a door for each floor on offer. Draws an
## ElevatorVM and forwards the ride.

## The run has moved to another screen.
signal moved

const HEAT: Rect2 = Rect2(44.0, 86.0, 72.0, 290.0)
const DOORS: Rect2 = Rect2(128.0, 86.0, 672.0, 290.0)
const BAR: Rect2 = Rect2(4.0, 0.0, 20.0, 150.0)
const MONEY_WIDTH: float = 212.0

var _vm: ElevatorVM
var _frame: DesignFrame
var _meter: Control


func _init(vm: ElevatorVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new())
	_build_title()
	_build_money()
	_build_heat()
	var doors: HBoxContainer = HBoxContainer.new()
	doors.position = DOORS.position
	doors.custom_minimum_size = DOORS.size
	doors.size = DOORS.size
	doors.add_theme_constant_override("separation", 16)
	_frame.add_child(doors)
	var options: Array[ElevatorOption] = _vm.options()
	for i: int in options.size():
		doors.add_child(_door(i, options[i]))


func _build_title() -> void:
	var panel: PanelContainer = _slip(Vector2(HEAT.position.x, 10.0), -1.5)
	var column: VBoxContainer = _stack(-3)
	panel.add_child(column)
	column.add_child(_left(UiKit.label(_vm.heading(), Fonts.Face.LABEL, 11, Palette.MUTED)))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	column.add_child(row)
	row.add_child(Icons.rect("icons/elevator", 18.0, Palette.CREAM))
	row.add_child(UiKit.label(ElevatorVM.TITLE, Fonts.Face.TITLE, 18, Palette.CREAM))
	column.add_child(_left(UiKit.label(_vm.hint(), Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)))


## The bankroll carried in, against the next floor's quota.
func _build_money() -> void:
	var panel: PanelContainer = _slip(Vector2(DOORS.end.x - MONEY_WIDTH, 10.0), 1.0)
	panel.custom_minimum_size.x = MONEY_WIDTH
	_frame.add_child(UiKit.tape(Vector2(DOORS.end.x - 190.0, 4.0), Vector2(40.0, 13.0), -4.0))
	var column: VBoxContainer = _stack(1)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = _left(
		UiKit.label("BANKROLL CARRIED IN", Fonts.Face.LABEL, 11, Palette.MUTED)
	)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	top.add_child(UiKit.label(_vm.bankroll_text(), Fonts.Face.NUMBER, 21, Palette.CREAM))
	var bar: ShareBar = ShareBar.new(Vector2(0.0, 10.0), Palette.GOLD)
	bar.show_share(_vm.quota_share())
	column.add_child(bar)
	var foot: HBoxContainer = HBoxContainer.new()
	column.add_child(foot)
	var quota: Label = _left(UiKit.label(_vm.quota_text(), Fonts.Face.BODY_HEAVY, 10, Palette.MUTED))
	quota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(quota)
	foot.add_child(UiKit.label(_vm.gap_text(), Fonts.Face.BODY_HEAVY, 10, Palette.CREAM))


## Run heat now, and what the ride takes off it.
func _build_heat() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel()
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	panel.position = HEAT.position
	panel.custom_minimum_size = HEAT.size
	_frame.add_child(panel)
	var column: VBoxContainer = _stack(5)
	panel.add_child(column)
	var caption: Label = UiKit.label("RUN\nHEAT", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.add_theme_constant_override("line_spacing", -3)
	column.add_child(caption)
	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(52.0, BAR.size.y)
	_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_meter.draw.connect(_draw_meter)
	column.add_child(_meter)
	column.add_child(UiKit.label(_vm.heat_text(), Fonts.Face.LABEL, 13, Palette.MUTED))
	column.add_child(Icons.rect("icons/down", 14.0, Palette.WIN))
	column.add_child(UiKit.label(_vm.heat_after_text(), Fonts.Face.NUMBER, 20, Palette.CREAM))
	var shed: Label = UiKit.chip(_vm.shed_text(), Palette.WIN, Palette.CHIP_INK, 10)
	shed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(shed)


## The bar: striped up to run heat now, solid up to the least the ride can
## leave, with a line at each mark.
func _draw_meter() -> void:
	var radius: int = roundi(BAR.size.x / 2.0)
	_meter.draw_style_box(UiKit.filled(Palette.OUTLINE, radius), BAR)
	var inner: Rect2 = BAR.grow(-2.0)
	_meter.draw_style_box(UiKit.filled(Palette.WELL, radius - 2), inner)
	var now: float = inner.size.y * _vm.heat_share()
	var after: float = inner.size.y * _vm.heat_after_share()
	var y: float = inner.end.y - now
	while y < inner.end.y - after:
		_meter.draw_rect(Rect2(inner.position.x, y, inner.size.x, 2.0), Color(Palette.RUN_HEAT, 0.55))
		y += 5.0
	if after > 0.0:
		_meter.draw_rect(
			Rect2(inner.position.x, inner.end.y - after, inner.size.x, after), Palette.RUN_HEAT
		)
	var hud: FloorHudVM = _vm.hud()
	var marks: Array[int] = hud.heat_marks()
	var shares: Array[float] = hud.heat_mark_shares()
	var font: Font = Fonts.of(Fonts.Face.NUMBER)
	for i: int in marks.size():
		var at: float = maxf(BAR.end.y - BAR.size.y * shares[i], 1.0)
		_meter.draw_rect(Rect2(2.0, at, 24.0, 2.0), Palette.CREAM)
		_meter.draw_string(
			font, Vector2(29.0, at + 6.0), str(marks[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Palette.MUTED
		)


## One floor on offer: its signature, what it asks, and the ride.
func _door(index: int, option: ElevatorOption) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = UiKit.panel_column(panel, 12, 6)
	column.add_child(_left(UiKit.label(option.door, Fonts.Face.LABEL, 11, Palette.MUTED)))
	var names: VBoxContainer = _stack(-3)
	column.add_child(names)
	names.add_child(_left(UiKit.label(option.name, Fonts.Face.TITLE, 22, Palette.CREAM)))
	var plain: Label = _left(UiKit.label(option.plain, Fonts.Face.BODY_HEAVY, 12, Palette.MUTED))
	plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plain.add_theme_constant_override("line_spacing", -2)
	names.add_child(plain)
	var facts: PanelContainer = PanelContainer.new()
	var inset: StyleBoxFlat = ShopCards.inset()
	inset.content_margin_top = 4
	inset.content_margin_bottom = 4
	facts.add_theme_stylebox_override("panel", inset)
	facts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(facts)
	var rows: VBoxContainer = _stack(0)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.add_child(rows)
	rows.add_child(_fact("QUOTA", option.quota_text, 20))
	if not option.marker_text.is_empty():
		var debt: Label = UiKit.label(option.marker_text, Fonts.Face.BODY_HEAVY, 10, Palette.RUN_HEAT)
		debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rows.add_child(debt)
	rows.add_child(_fact("STAKES", option.stakes_text, 13))
	var clock: HBoxContainer = _fact("CLOCK", option.hands_text, 20)
	var note: Label = UiKit.label(
		option.clock_note, Fonts.Face.LABEL, 12,
		Palette.RUN_HEAT if option.short_clock else Palette.MUTED
	)
	clock.add_child(note)
	clock.move_child(note, 1)
	rows.add_child(clock)
	var ride: Button = UiKit.button(option.ride_text, true, 16)
	ride.icon = Icons.of("icons/up")
	ride.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ride.add_theme_constant_override("icon_max_width", 18)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		ride.add_theme_color_override(colour, Palette.PANEL)
	ride.custom_minimum_size.y = 46.0
	ride.pressed.connect(_on_ride.bind(index))
	column.add_child(ride)
	return panel


## "QUOTA ........ $560,000" inside a door.
func _fact(caption: String, value: String, size: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name: Label = _left(UiKit.label(caption, Fonts.Face.LABEL, 11, Palette.MUTED))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(UiKit.label(value, Fonts.Face.NUMBER, size, Palette.CREAM))
	return row


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
	return label


## For scripts/shot: rides to the floor behind this door.
func _shot_pick(index: int) -> void:
	_on_ride(index)


func _on_ride(index: int) -> void:
	_vm.ride(index)
	moved.emit()
