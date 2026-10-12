class_name ChipPile
extends Control
## Draws a sum of money as betting chips, seen from above as on the design
## canvas: one stack per denomination side by side (ChipStacks), each chip a
## disc with a dashed rim, the ones under it showing as its edge. With no
## chips it draws the empty betting spot. The pile sits on the control's
## bottom edge.

## A face and an edge colour per denomination, $100 first: white, red, blue,
## green, black, purple, gold, then orange for anything beyond.
const COLOURS: Array[Color] = [
	Palette.CREAM, Color("B8AA88"),
	Palette.CARD_RED, Color("7E2F24"),
	Color("3F6FB5"), Color("284A7C"),
	Color("4F9A6B"), Color("2F6B45"),
	Color("2A2F3D"), Color("12151D"),
	Color("7B5AA6"), Color("4E3670"),
	Palette.GOLD, Palette.GOLD_EDGE,
	Color("E08A4A"), Color("A85F2C"),
]
const DASHES: int = 8
## How far each stack sits from the last, in chip widths.
const SPREAD: float = 0.74

var _stacks: Array[ChipStacks.Stack] = []
var _diameter: float = 34.0
var _lift: float = 3.0


## amount in chips of this diameter, each lifting its stack by lift pixels.
func show_amount(amount: int, diameter: float, lift: float) -> void:
	_stacks = ChipStacks.of(amount)
	_diameter = diameter
	_lift = lift
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## How wide the pile for amount draws at this diameter.
static func width_of(amount: int, diameter: float) -> float:
	var stacks: int = maxi(ChipStacks.of(amount).size(), 1)
	return diameter * (1.0 + (stacks - 1) * SPREAD)


func _draw() -> void:
	var radius: float = _diameter / 2.0
	if _stacks.is_empty():
		var spot: Vector2 = Vector2(radius, size.y - radius)
		_rim(spot, radius - 1.0, Color(Palette.GOLD, 0.6), 1.5)
		return
	for i: int in _stacks.size():
		var stack: ChipStacks.Stack = _stacks[i]
		var colour: int = mini(stack.denomination, COLOURS.size() / 2 - 1) * 2
		var face: Color = COLOURS[colour]
		var edge: Color = COLOURS[colour + 1]
		var x: float = radius + i * _diameter * SPREAD
		var top: float = size.y - radius - (stack.count - 1) * _lift
		for under: int in range(stack.count - 1, 0, -1):
			var at: Vector2 = Vector2(x, top + under * _lift)
			draw_circle(at, radius, edge if under % 2 == 1 else face, true, -1.0, true)
		draw_circle(Vector2(x, top), radius, face, true, -1.0, true)
		draw_arc(Vector2(x, top), radius - 0.5, 0.0, TAU, 32, edge, 1.0, true)
		# A white chip's rim would vanish in cream, so it takes its edge colour.
		var rim: Color = Palette.CARD_RED if stack.denomination == 0 else Palette.CREAM
		_rim(Vector2(x, top), radius * 0.84, rim, radius * 0.22)


## A dashed ring: a chip's rim, or an empty spot's outline.
func _rim(centre: Vector2, radius: float, color: Color, width: float) -> void:
	var dash: float = TAU / DASHES
	for i: int in DASHES:
		draw_arc(centre, radius, i * dash, i * dash + dash * 0.55, 6, color, width, true)
