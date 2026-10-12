class_name CardFace
extends Control
## Draws one CardView at any width, to the canvas's Card component: a cream
## face with the rank and suit in two corners and a large suit, or the
## oxblood back. A mark is a gold badge on the top right corner, face up or
## down (spec §2.5). A taped card (§2.3) wears a strip of masking tape over
## each corner's rank, with the rank it now reads as scribbled on the tape;
## face down it wears none.
##
## On the deck screen a card also wears the look of its last permanent
## change (spec §4.1): a Cold Seal's blue wax seal, Permanent Ink's rank
## rewritten in marker, a reforge's gold foil edge, or an added card's green
## edge and plus. Only ever on the face: a back that showed one would be a
## free mark.

## How a strip of tape lies: at a slant over the rank alone, across the
## card over the rank's row, or down the card over the rank's column.
enum TapeShape { DIAGONAL, ACROSS, DOWN }

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
const DIAGONAL_ANGLE: float = -0.5
## How far off true a long strip sits.
const SKEW: float = 0.03
const SCRIBBLE_ANGLE: float = -0.14

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
	if _view.peeked:
		# Seen through the camera: the table still has it face down.
		var seen: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, roundi(_width * 0.07))
		seen.draw_center = false
		seen.set_border_width_all(2)
		seen.border_color = Palette.TEAL
		draw_style_box(seen, rect)
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
	var half_turn: Transform2D = Transform2D(PI, size)
	for corner: Transform2D in [Transform2D.IDENTITY, half_turn]:
		draw_set_transform_matrix(corner)
		if _view.change == CardView.Change.INKED:
			_draw_inked_corner(corner, suit, ink)
		else:
			_draw_corner(suit, ink)
	draw_set_transform(Vector2.ZERO)
	match _view.change:
		CardView.Change.SEALED:
			_draw_seal()
		CardView.Change.REFORGED:
			_draw_edge(Palette.GOLD)
		CardView.Change.ADDED:
			_draw_edge(Palette.ADDED)
			_draw_plus()


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


## Permanent Ink: the corner's rank written in marker, a little off level
## and underlined, over the printed suit.
func _draw_inked_corner(corner: Transform2D, suit: Texture2D, ink: Color) -> void:
	var pad: float = _width * 0.08
	var pip: float = _width * 0.17
	var font: Font = Fonts.of(Fonts.Face.TITLE)
	var font_size: int = roundi(_width * 0.3)
	var text: String = _view.rank_text()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spot: Vector2 = Vector2(pad + maxf(width, pip) / 2.0, pad + font_size * 0.36)
	draw_texture_rect(
		suit, Rect2(spot.x - pip / 2.0, pad + font_size * 0.92, pip, pip), false, ink
	)
	draw_set_transform_matrix(corner * Transform2D(SCRIBBLE_ANGLE, spot))
	var at: Vector2 = Vector2(-width / 2.0, font_size * 0.36)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.MARKER)
	var under: float = at.y + font_size * 0.12
	var stroke: float = maxf(1.5, _width * 0.03)
	draw_line(
		Vector2(-width * 0.6, under), Vector2(width * 0.6, under), Palette.MARKER, stroke, true
	)


## A Cold Seal: a round of blue wax pressed on the lower left, with a frost
## star in it.
func _draw_seal() -> void:
	var radius: float = _width * 0.15
	var centre: Vector2 = Vector2(_width * 0.25, size.y - _width * 0.5)
	draw_circle(centre + Vector2(0.0, _width * 0.02), radius, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(centre, radius, Palette.SEAL.darkened(0.3), true, -1.0, true)
	draw_circle(centre, radius * 0.8, Palette.SEAL, true, -1.0, true)
	var stroke: float = maxf(1.0, _width * 0.025)
	for spoke: int in 3:
		var arm: Vector2 = Vector2.from_angle(spoke * PI / 3.0) * radius * 0.55
		draw_line(centre - arm, centre + arm, Palette.CREAM, stroke, true)


## A coloured edge all round the face.
func _draw_edge(color: Color) -> void:
	var edge: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, roundi(_width * 0.07))
	edge.draw_center = false
	edge.set_border_width_all(maxi(2, roundi(_width * 0.05)))
	edge.border_color = color
	draw_style_box(edge, Rect2(Vector2.ZERO, size))


## An added card's plus, on the lower left.
func _draw_plus() -> void:
	var radius: float = _width * 0.12
	var centre: Vector2 = Vector2(_width * 0.25, size.y - _width * 0.5)
	draw_circle(centre, radius, Palette.ADDED, true, -1.0, true)
	var arm: float = radius * 0.55
	var stroke: float = maxf(1.5, _width * 0.035)
	draw_line(centre - Vector2(arm, 0.0), centre + Vector2(arm, 0.0), Palette.CREAM, stroke, true)
	draw_line(centre - Vector2(0.0, arm), centre + Vector2(0.0, arm), Palette.CREAM, stroke, true)


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


## Two strips of masking tape, one over each corner's rank, with the rank
## the card now reads as scribbled on them. The second strip is the first
## turned half round, as the corners are; the card's id picks each strip's
## shape, so a card keeps its look.
func _draw_tape() -> void:
	var half_turn: Transform2D = Transform2D(PI, size)
	var shapes: int = TapeShape.size()
	_draw_strip(Transform2D.IDENTITY, posmod(_view.id, shapes) as TapeShape)
	_draw_strip(half_turn, posmod(_view.id / shapes + _view.id, shapes) as TapeShape)
	draw_set_transform(Vector2.ZERO)


func _draw_strip(corner: Transform2D, shape: TapeShape) -> void:
	# Where the corner's rank is printed.
	var spot: Vector2 = Vector2(_width * 0.2, _width * 0.2)
	var thick: float = _width * 0.3
	var strip: Rect2
	var centre: Vector2 = spot
	var angle: float = 0.0
	match shape:
		TapeShape.DIAGONAL:
			strip = Rect2(-_width * 0.33, -thick / 2.0, _width * 0.66, thick)
			angle = DIAGONAL_ANGLE
		TapeShape.ACROSS:
			strip = Rect2(-size.x * 0.56, -thick / 2.0, size.x * 1.12, thick)
			centre.x = size.x / 2.0
			angle = -SKEW
		TapeShape.DOWN:
			strip = Rect2(-thick / 2.0, -size.y * 0.54, thick, size.y * 1.08)
			centre.y = size.y / 2.0
			angle = SKEW
	draw_set_transform_matrix(corner * Transform2D(angle, centre))
	draw_rect(strip.grow(1.0), Color(0, 0, 0, 0.18))
	draw_rect(strip, Color(Palette.TAPE, 0.96))
	var crease: Color = Color(Palette.TAPE.darkened(0.16), 0.6)
	if strip.size.x > strip.size.y:
		var y: float = strip.position.y + strip.size.y * 0.78
		draw_line(Vector2(strip.position.x, y), Vector2(strip.end.x, y), crease, 1.0)
	else:
		var x: float = strip.position.x + strip.size.x * 0.78
		draw_line(Vector2(x, strip.position.y), Vector2(x, strip.end.y), crease, 1.0)
	# The scribble: the rank in marker, a little off level.
	var font: Font = Fonts.of(Fonts.Face.TITLE)
	var font_size: int = roundi(_width * 0.25)
	var text: String = _view.rank_text()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform_matrix(corner * Transform2D(SCRIBBLE_ANGLE, spot))
	var at: Vector2 = Vector2(-width / 2.0, font_size * 0.36)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.MARKER)


func _draw_mark() -> void:
	var badge: float = _width * 0.3
	var centre: Vector2 = Vector2(size.x + _width * 0.08 - badge / 2.0, badge / 2.0 - _width * 0.08)
	draw_circle(centre, badge / 2.0, Palette.PANEL, true, -1.0, true)
	draw_circle(centre, badge / 2.0 - 1.5, Palette.GOLD, true, -1.0, true)
	var symbol: float = badge * 0.64
	var mark: Texture2D = MARKS[_view.symbol % MARKS.size()]
	var at: Rect2 = Rect2(centre - Vector2(symbol, symbol) / 2.0, Vector2(symbol, symbol))
	draw_texture_rect(mark, at, false, Palette.PANEL)
