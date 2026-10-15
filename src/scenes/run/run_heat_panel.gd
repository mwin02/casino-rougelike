class_name RunHeatPanel
extends PanelContainer
## Run heat (spec §7.4) down the left of a floor screen: a tall bar with a
## mark at the pit boss, the sweep and ejection, the heat as a number, and a
## chip once the pit boss is on the floor.

const SIZE: Vector2 = Vector2(72.0, 290.0)
const BAR: Rect2 = Rect2(4.0, 0.0, 20.0, 170.0)
const MARK_ICONS: Array[String] = ["icons/eye", "icons/siren", "icons/exit"]

var _hud: FloorHudVM
var _meter: Control
var _number: Label
var _boss: Label
## One under each mark's number.
var _mark_icons: Array[TextureRect] = []


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel()
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = SIZE
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var caption: Label = UiKit.label("RUN\nHEAT", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.add_theme_constant_override("line_spacing", -3)
	column.add_child(caption)
	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(52.0, BAR.size.y)
	_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_meter.draw.connect(_draw_meter)
	column.add_child(_meter)
	for icon: String in MARK_ICONS:
		var art: TextureRect = Icons.rect(icon, 14.0, Palette.MUTED)
		art.size = Vector2(14.0, 14.0)
		_meter.add_child(art)
		_mark_icons.append(art)
	_number = UiKit.label("", Fonts.Face.NUMBER, 24, Palette.CREAM)
	column.add_child(_number)
	_boss = UiKit.chip("Pit boss", Palette.ALERT, Palette.CHIP_INK)
	_boss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_boss)


func refresh(hud: FloorHudVM) -> void:
	_hud = hud
	_number.text = hud.run_heat_text()
	_boss.visible = hud.pit_boss()
	_meter.queue_redraw()


func _draw_meter() -> void:
	if _hud == null:
		return
	var radius: int = roundi(BAR.size.x / 2.0)
	_meter.draw_style_box(UiKit.filled(Palette.OUTLINE, radius), BAR)
	var inner: Rect2 = BAR.grow(-2.0)
	_meter.draw_style_box(UiKit.filled(Palette.WELL, radius - 2), inner)
	var fill: float = inner.size.y * _hud.run_heat_share()
	if fill > 0.0:
		var box: StyleBoxFlat = UiKit.filled(Palette.RUN_HEAT, radius - 2)
		box.corner_radius_top_left = 0
		box.corner_radius_top_right = 0
		_meter.draw_style_box(
			box, Rect2(inner.position.x, inner.end.y - fill, inner.size.x, fill)
		)
	var marks: Array[int] = _hud.heat_marks()
	var shares: Array[float] = _hud.heat_mark_shares()
	var font: Font = Fonts.of(Fonts.Face.NUMBER)
	var reached: Array[bool] = _hud.heat_marks_reached()
	for i: int in marks.size():
		var y: float = maxf(BAR.end.y - BAR.size.y * shares[i], 1.0)
		_meter.draw_rect(Rect2(2.0, y, 24.0, 2.0), Palette.CREAM)
		var ink: Color = Palette.ALERT if reached[i] else Palette.CREAM
		_meter.draw_string(
			font, Vector2(29.0, y + 6.0), str(marks[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink
		)
		_mark_icons[i].position = Vector2(31.0, y + 9.0)
		_mark_icons[i].modulate = Palette.ALERT if reached[i] else Palette.MUTED
