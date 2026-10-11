class_name HeatMeter
extends PanelContainer
## The table's heat meter, to the canvas: a tall bar filled in its tier's
## colour with a tick at each tier edge, the heat as a number, where pending
## heat would take it, and the tier as a chip. Draws a HeatMeterVM.

const BAR_SIZE: Vector2 = Vector2(20, 120)
const TIER_INK: Color = Color("10151F")

var _vm: HeatMeterVM
var _bar: Control
var _number: Label
var _projected: Label
var _tier: Label


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel()
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	column.add_child(UiKit.label("HEAT", Fonts.Face.LABEL, 11, Palette.MUTED))
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)
	_number = UiKit.label("", Fonts.Face.NUMBER, 22, Palette.CREAM)
	column.add_child(_number)
	_projected = UiKit.label("", Fonts.Face.NUMBER, 15, Palette.GOLD)
	column.add_child(_projected)
	_tier = UiKit.chip("", Palette.TIERS[0], TIER_INK)
	_tier.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_tier)


func show_meter(vm: HeatMeterVM) -> void:
	_vm = vm
	_number.text = vm.heat_text()
	_projected.text = vm.projected_text()
	_projected.visible = vm.has_projection()
	_tier.text = vm.tier_name()
	var ground: StyleBoxFlat = _tier.get_theme_stylebox("normal")
	ground.bg_color = Palette.TIERS[vm.tier()]
	_bar.queue_redraw()


func _draw_bar() -> void:
	if _vm == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	var radius: int = roundi(rect.size.x / 2.0)
	_bar.draw_style_box(UiKit.filled(Palette.WELL, radius), rect)
	var inner: Rect2 = rect.grow(-2.0)
	var fill: float = inner.size.y * _vm.fill_fraction()
	var projected: float = inner.size.y * _vm.projected_fraction()
	if _vm.has_projection():
		_fill(inner, projected, Palette.GOLD.darkened(0.45))
		_stripes(inner, fill, projected)
	_fill(inner, fill, Palette.TIERS[_vm.tier()])
	for edge: float in _vm.edge_fractions():
		_tick(inner, edge, Color(Palette.GOLD, 0.45))
	if _vm.has_floor():
		_tick(inner, _vm.floor_fraction(), Palette.CREAM)
	var outline: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, radius)
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = Palette.OUTLINE
	_bar.draw_style_box(outline, rect)


## Fills inner from the bottom to height, rounded like the bar's end.
func _fill(inner: Rect2, height: float, color: Color) -> void:
	if height <= 0.0:
		return
	var box: StyleBoxFlat = UiKit.filled(color, roundi(inner.size.x / 2.0))
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	_bar.draw_style_box(box, Rect2(inner.position.x, inner.end.y - height, inner.size.x, height))


## Gold stripes over the pending part of the bar, between two heights.
func _stripes(inner: Rect2, from: float, to: float) -> void:
	var y: float = inner.end.y - to
	while y < inner.end.y - from:
		var right: Vector2 = Vector2(inner.end.x, y)
		_bar.draw_line(Vector2(inner.position.x, y + 4.0), right, Palette.GOLD, 1.5, true)
		y += 4.0


func _tick(inner: Rect2, fraction: float, color: Color) -> void:
	var y: float = inner.end.y - inner.size.y * fraction
	_bar.draw_rect(Rect2(inner.position.x, y - 1.0, inner.size.x, 2.0), color)
