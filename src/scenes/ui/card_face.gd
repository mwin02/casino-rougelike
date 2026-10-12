class_name CardFace
extends Control
## Draws one CardView at any width, to the canvas's Card component: a cream
## face with the rank and suit in two corners and a large suit, or the
## oxblood back. A mark is a gold badge on the top right corner, face up or
## down (spec §2.5); a taped card wears a strip of masking tape (§2.3).

const ASPECT: float = 1.4
const SUITS: Array[Texture2D] = [
	preload("res://assets/cards/suit_clubs.svg"),
	preload("res://assets/cards/suit_diamonds.svg"),
	preload("res://assets/cards/suit_hearts.svg"),
	preload("res://assets/cards/suit_spades.svg"),
]
const MARKS: Array[Texture2D] = [
	preload("res://assets/cards/mark_1_star.svg"),
	preload("res://assets/cards/mark_2_moon.svg"),
	preload("res://assets/cards/mark_3_bolt.svg"),
	preload("res://assets/cards/mark_4_drop.svg"),
	preload("res://assets/cards/mark_5_ring.svg"),
]
const DIM_ALPHA: float = 0.55
const HATCH_STEP: float = 8.0
const TAPE_ANGLE: float = -0.3

var _view: CardView
var _width: float = 72.0


func show_card(view: CardView, width: float) -> void:
	_view = view
	_width = width
	custom_minimum_size = Vector2(width, roundf(width * ASPECT))
	size = custom_minimum_size
	modulate.a = DIM_ALPHA if view.dimmed else 1.0
	queue_redraw()


func _draw() -> void:
	if _view == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if _view.face_down:
		_draw_back(rect)
	else:
		_draw_face(rect)
	if _view.taped:
		_draw_tape()
	if _view.is_marked():
		_draw_mark()


func _body(color: Color, edge: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = UiKit.filled(color, roundi(_width * 0.07))
	box.border_color = edge
	box.shadow_color = UiKit.SHADOW
	box.shadow_size = roundi(_width * 0.1)
	box.shadow_offset = Vector2(0, _width * 0.06)
	return box


func _draw_face(rect: Rect2) -> void:
	var body: StyleBoxFlat = _body(Palette.CREAM, Palette.CREAM_EDGE)
	body.set_border_width_all(1)
	draw_style_box(body, rect)
	var ink: Color = Palette.CARD_RED if _view.is_red() else Palette.CARD_BLACK
	var suit: Texture2D = SUITS[_view.suit]
	var big: float = _width * 0.46
	var centre: Vector2 = Vector2(size.x * 0.5, size.y * 0.56)
	draw_texture_rect(suit, Rect2(centre - Vector2(big, big) / 2.0, Vector2(big, big)), false, ink)
	_draw_corner(suit, ink)
	draw_set_transform(size, PI)
	_draw_corner(suit, ink)
	draw_set_transform(Vector2.ZERO)


## The rank over a small suit, centred on each other, in the top left.
func _draw_corner(suit: Texture2D, ink: Color) -> void:
	var font: Font = Fonts.of(Fonts.Face.CARD)
	var font_size: int = roundi(_width * 0.27)
	var pad: float = _width * 0.08
	var pip: float = _width * 0.17
	var text: String = _view.rank_text()
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var column: float = maxf(text_width, pip)
	var top: float = pad - font_size * 0.12
	var baseline: Vector2 = Vector2(
		pad + (column - text_width) / 2.0, top + font.get_ascent(font_size)
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var pip_at: Vector2 = Vector2(pad + (column - pip) / 2.0, pad + font_size * 0.92)
	draw_texture_rect(suit, Rect2(pip_at, Vector2(pip, pip)), false, ink)


func _draw_back(rect: Rect2) -> void:
	draw_style_box(_body(Palette.CARD_BACK, Palette.CARD_BACK.darkened(0.35)), rect)
	var inner: Rect2 = rect.grow(-_width * 0.08)
	var line: Color = Color(Palette.GOLD, 0.5)
	# A gold lattice: both diagonals, clipped to the inner frame.
	var reach: float = inner.size.x + inner.size.y
	var offset: float = 0.0
	while offset < reach:
		_hatch(inner, offset, 1.0, line)
		_hatch(inner, offset, -1.0, line)
		offset += HATCH_STEP * 1.414
	var frame: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, roundi(_width * 0.04))
	frame.draw_center = false
	frame.set_border_width_all(1)
	frame.border_color = Palette.GOLD
	draw_style_box(frame, inner)


## One lattice line across inner: down-right for slope 1, down-left for -1.
func _hatch(inner: Rect2, offset: float, slope: float, color: Color) -> void:
	var from: Vector2 = Vector2(offset, 0.0)
	var to: Vector2 = Vector2(offset - inner.size.y, inner.size.y)
	from.x = clampf(from.x, 0.0, inner.size.x)
	to.x = clampf(to.x, 0.0, inner.size.x)
	from.y = clampf(offset - from.x, 0.0, inner.size.y)
	to.y = clampf(offset - to.x, 0.0, inner.size.y)
	if slope < 0.0:
		from.x = inner.size.x - from.x
		to.x = inner.size.x - to.x
	draw_line(inner.position + from, inner.position + to, color, 1.0, true)


## A strip of masking tape across the lower half, a little askew, running
## just past both edges.
func _draw_tape() -> void:
	var length: float = _width * 1.24
	var height: float = _width * 0.26
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.66), TAPE_ANGLE)
	var strip: Rect2 = Rect2(-length / 2.0, -height / 2.0, length, height)
	draw_rect(strip.grow(1.0), Color(0, 0, 0, 0.18))
	draw_rect(strip, Color(Palette.TAPE, 0.94))
	var crease: Color = Color(Palette.TAPE.darkened(0.18), 0.7)
	for share: float in [0.3, 0.7]:
		var y: float = strip.position.y + height * share
		draw_line(Vector2(strip.position.x, y), Vector2(strip.end.x, y), crease, 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_mark() -> void:
	var badge: float = _width * 0.3
	var centre: Vector2 = Vector2(size.x + _width * 0.08 - badge / 2.0, badge / 2.0 - _width * 0.08)
	draw_circle(centre, badge / 2.0, Palette.PANEL, true, -1.0, true)
	draw_circle(centre, badge / 2.0 - 1.5, Palette.GOLD, true, -1.0, true)
	var symbol: float = badge * 0.64
	var mark: Texture2D = MARKS[_view.symbol % MARKS.size()]
	var at: Rect2 = Rect2(centre - Vector2(symbol, symbol) / 2.0, Vector2(symbol, symbol))
	draw_texture_rect(mark, at, false, Palette.PANEL)
