class_name TricksOverlay
extends Control
## Over the table while the Tricks screen is open: a darkened picture, and a
## tappable outline with its name on every card the action being picked can
## target.

signal picked(id: int)

const TINT: Color = Color(0.04, 0.06, 0.11, 0.3)
const TAG: Color = Color(0.05, 0.07, 0.11, 0.85)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## targets are the picker's card choices; rects is where each card is drawn.
func refresh(targets: Array[Choice], rects: Dictionary[int, Rect2]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for target: Choice in targets:
		if not rects.has(target.id):
			continue
		var rect: Rect2 = rects[target.id].grow(5.0)
		var outline: Button = Button.new()
		outline.focus_mode = Control.FOCUS_NONE
		outline.position = rect.position
		outline.size = rect.size
		for state: String in ["normal", "hover", "pressed"]:
			var box: StyleBoxFlat = UiKit.filled(Color(Palette.GOLD, 0.12), 11)
			box.set_border_width_all(2)
			box.border_color = Palette.TEAL if state == "pressed" else Palette.GOLD
			outline.add_theme_stylebox_override(state, box)
		outline.pressed.connect(picked.emit.bind(target.id))
		add_child(outline)
		var name: Label = UiKit.chip(target.label.to_upper(), TAG, Palette.TEAL, 10)
		name.add_theme_font_override("font", Fonts.of(Fonts.Face.CAMERA))
		name.position = Vector2(rect.position.x, rect.end.y + 3.0)
		add_child(name)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -2000.0, 4000.0 + size.x, 4000.0 + size.y), TINT)
