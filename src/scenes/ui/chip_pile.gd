class_name ChipPile
extends Control
## Draws a pile of betting chips, seen from above as on the design canvas:
## stacks standing side by side, each chip a disc with a dashed cream rim,
## the ones under it showing as its edge. With no chips it draws the empty
## betting spot. The pile sits on the control's bottom edge.

## Face and edge colour for each stack in turn.
const MAIN: Array[Color] = [
	Palette.CARD_RED, Color("7E2F24"), Palette.GOLD, Palette.GOLD_EDGE,
]
const SIDE: Array[Color] = [Palette.TEAL, Color("5E8E84")]
const DASHES: int = 8

var _count: int = 0
var _diameter: float = 34.0
var _per_stack: int = 5
var _lift: float = 3.0
var _colours: Array[Color] = MAIN


## count chips, per_stack to a stack, each lifting the stack by lift pixels.
func show_chips(
	count: int, diameter: float, per_stack: int, lift: float, colours: Array[Color] = MAIN
) -> void:
	_count = count
	_diameter = diameter
	_per_stack = per_stack
	_lift = lift
	_colours = colours
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var radius: float = _diameter / 2.0
	if _count <= 0:
		var spot: Vector2 = Vector2(radius, size.y - radius)
		_rim(spot, radius - 1.0, Color(Palette.GOLD, 0.6), 1.5)
		return
	var stacks: int = ceili(float(_count) / _per_stack)
	for stack: int in stacks:
		var chips: int = mini(_count - stack * _per_stack, _per_stack)
		var face: Color = _colours[stack * 2 % _colours.size()]
		var edge: Color = _colours[(stack * 2 + 1) % _colours.size()]
		var x: float = radius + stack * _diameter * 0.72
		var top: float = size.y - radius - (chips - 1) * _lift
		for under: int in range(chips - 1, 0, -1):
			var at: Vector2 = Vector2(x, top + under * _lift)
			draw_circle(at, radius, edge if under % 2 == 1 else face, true, -1.0, true)
		draw_circle(Vector2(x, top), radius, face, true, -1.0, true)
		_rim(Vector2(x, top), radius * 0.86, Palette.CREAM, radius * 0.24)


## A dashed ring: a chip's rim, or an empty spot's outline.
func _rim(centre: Vector2, radius: float, color: Color, width: float) -> void:
	var dash: float = TAU / DASHES
	for i: int in DASHES:
		draw_arc(centre, radius, i * dash, i * dash + dash * 0.55, 6, color, width, true)
