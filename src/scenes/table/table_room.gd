class_name TableRoom
extends Control
## The room behind the table, drawn to the design canvas: the back wall
## with its lamp, plant and camera dome, the dealer's silhouette, and the
## felt inside its wooden rail with the game's name printed on it. It draws
## in the design frame's pixels and runs past the frame on both sides.

const WALL_HEIGHT: float = 140.0
const SPILL: float = 2000.0
const FELT_CENTRE: Vector2 = Vector2(422.0, 430.0)
const FELT_RADII: Vector2 = Vector2(572.0, 330.0)
const RAIL: float = 16.0
const SHADOW: Color = Color("121828")
const OXBLOOD: Color = Color("6E2A2C")
const LEAVES: Array[Color] = [Color("3F6B57"), Color("355C4A"), Color("4A7A62")]

var _felt_lines: PackedStringArray = []


func show_felt(lines: PackedStringArray) -> void:
	_felt_lines = lines
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-SPILL, -SPILL, SPILL * 2.0 + size.x, SPILL + WALL_HEIGHT), Palette.WALL)
	var x: float = -SPILL + fposmod(SPILL, 136.0) + 132.0
	while x < size.x + SPILL:
		draw_rect(Rect2(x, -SPILL, 4.0, SPILL + WALL_HEIGHT), Color(Palette.GOLD, 0.06))
		x += 136.0
	_draw_lamp()
	_draw_plant()
	_draw_camera()
	_draw_dealer()
	_draw_felt()


func _draw_lamp() -> void:
	for ring: int in 30:
		draw_circle(Vector2(245.0, 25.0), 95.0 - ring * 3.0, Color(Palette.GOLD, 0.012))
	var chair: StyleBoxFlat = UiKit.filled(OXBLOOD, 10)
	chair.corner_radius_top_left = 30
	chair.corner_radius_top_right = 30
	chair.border_color = OXBLOOD.darkened(0.35)
	chair.border_width_bottom = 3
	draw_style_box(chair, Rect2(196.0, 58.0, 92.0, 65.0))
	draw_rect(Rect2(248.0, -SPILL, 4.0, SPILL + 22.0), SHADOW)
	var shade: PackedVector2Array = [
		Vector2(236.5, 22.0), Vector2(263.5, 22.0), Vector2(274.0, 52.0), Vector2(226.0, 52.0),
	]
	draw_colored_polygon(shade, Palette.GOLD)


func _draw_plant() -> void:
	var leaves: Array[Rect2] = [
		Rect2(600.0, 50.0, 26.0, 62.0), Rect2(622.0, 38.0, 24.0, 72.0),
		Rect2(640.0, 54.0, 24.0, 58.0),
	]
	var turns: Array[float] = [-24.0, 8.0, 30.0]
	for i: int in leaves.size():
		var leaf: Rect2 = leaves[i]
		_ellipse(leaf.get_center(), leaf.size / 2.0, LEAVES[i], deg_to_rad(turns[i]))
	var pot: StyleBoxFlat = UiKit.filled(OXBLOOD, 4)
	pot.corner_radius_bottom_left = 10
	pot.corner_radius_bottom_right = 10
	draw_style_box(pot, Rect2(630.0, 96.0, 30.0, 26.0))


func _draw_camera() -> void:
	draw_rect(Rect2(548.0, -SPILL, 6.0, SPILL + 8.0), SHADOW)
	var dome: StyleBoxFlat = UiKit.filled(Color("0E131F"), 0)
	dome.corner_radius_bottom_left = 19
	dome.corner_radius_bottom_right = 19
	dome.border_color = Palette.GOLD
	dome.border_width_left = 2
	dome.border_width_right = 2
	dome.border_width_bottom = 2
	draw_style_box(dome, Rect2(532.0, 6.0, 38.0, 20.0))
	draw_circle(Vector2(551.0, 17.0), 7.0, Color(Palette.LOSS, 0.25))
	draw_circle(Vector2(551.0, 17.0), 4.0, Color("E0604A"), true, -1.0, true)


## Head and shoulders, cut off by the top of the screen, in a bow tie.
func _draw_dealer() -> void:
	var body: StyleBoxFlat = UiKit.filled(Color("151B2B"), 0)
	body.corner_radius_top_left = 96
	body.corner_radius_top_right = 96
	draw_style_box(body, Rect2(312.0, -20.0, 220.0, 150.0))
	var shirt: PackedVector2Array = [
		Vector2(392.0, -20.0), Vector2(452.0, -20.0), Vector2(422.0, 80.0),
	]
	draw_colored_polygon(shirt, Color("E9DDBF"))
	var left: PackedVector2Array = [Vector2(402.0, 26.0), Vector2(420.0, 35.0), Vector2(402.0, 44.0)]
	var right: PackedVector2Array = [Vector2(442.0, 26.0), Vector2(424.0, 35.0), Vector2(442.0, 44.0)]
	draw_colored_polygon(left, Palette.CARD_RED)
	draw_colored_polygon(right, Palette.CARD_RED)
	draw_style_box(UiKit.filled(Color("7E2F24"), 2), Rect2(418.0, 31.0, 8.0, 8.0))
	draw_style_box(UiKit.filled(Palette.GOLD, 2), Rect2(464.0, 62.0, 24.0, 8.0))


func _draw_felt() -> void:
	_ellipse(FELT_CENTRE + Vector2(0.0, -5.0), FELT_RADII, Palette.RAIL_EDGE)
	_ellipse(FELT_CENTRE, FELT_RADII, Palette.RAIL)
	_ellipse(FELT_CENTRE, FELT_RADII - Vector2(RAIL, RAIL), Palette.FELT)
	var inset: Vector2 = FELT_RADII - Vector2(RAIL + 1.0, RAIL + 1.0)
	var line: PackedVector2Array = _ellipse_points(FELT_CENTRE, inset)
	line.append(line[0])
	draw_polyline(line, Color(Palette.GOLD, 0.55), 2.0, true)
	if _felt_lines.size() > 0:
		_draw_arc_text(_felt_lines[0])
	if _felt_lines.size() > 1:
		var font: Font = Fonts.of(Fonts.Face.NUMBER)
		var width: float = 400.0
		draw_string(
			font, Vector2(422.0 - width / 2.0, 236.0), _spaced(_felt_lines[1]),
			HORIZONTAL_ALIGNMENT_CENTER, width, 11, Color(Palette.GOLD, 0.55)
		)


## A filled ellipse, turned by turn radians about its centre.
func _ellipse(centre: Vector2, radii: Vector2, color: Color, turn: float = 0.0) -> void:
	draw_colored_polygon(_ellipse_points(centre, radii, turn), color)


func _ellipse_points(centre: Vector2, radii: Vector2, turn: float = 0.0) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for step: int in 180:
		var angle: float = TAU * step / 180.0
		points.append(centre + (Vector2(cos(angle), sin(angle)) * radii).rotated(turn))
	return points


## The felt's title, each letter set along a shallow arch.
func _draw_arc_text(text: String) -> void:
	var font: Font = Fonts.of(Fonts.Face.NUMBER)
	var font_size: int = 16
	var spacing: float = 3.0
	var widths: Array[float] = []
	var total: float = 0.0
	for letter: String in text:
		widths.append(font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		total += widths[-1] + spacing
	# A circle through the canvas's arch: 320 wide, 20 high, topping at y 196.
	var radius: float = 650.0
	var centre: Vector2 = Vector2(422.0, 196.0 + radius)
	var along: float = -total / 2.0
	for i: int in text.length():
		var angle: float = (along + widths[i] / 2.0) / radius
		var at: Vector2 = centre + Vector2(sin(angle), -cos(angle)) * radius
		draw_set_transform(at, angle)
		draw_string(
			font, Vector2(-widths[i] / 2.0, 0.0), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(Palette.GOLD, 0.7)
		)
		along += widths[i] + spacing
	draw_set_transform(Vector2.ZERO)


static func _spaced(text: String) -> String:
	return " ".join(text.split(""))
