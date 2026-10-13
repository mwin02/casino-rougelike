class_name MapBoard
extends Control
## The floor map's nodes on their panel, to the design canvas: rows run left
## to right, lanes top to bottom, each node linked to the next row. The map
## is wider than its panel and slides sideways. Draws MapNodeViews; a tapped
## node is picked.

signal picked(row: int, lane: int)

const SIZE: Vector2 = Vector2(448.0, 290.0)
const NODE: float = 48.0
const ROW_STEP: float = 72.0
const LANE_STEP: float = 80.0
## The first node's centre on the sliding canvas.
const FIRST: Vector2 = Vector2(44.0, 54.0)
## The canvas runs under the caption, so a YOU chip over the top lane shows.
const CANVAS_HEIGHT: float = 258.0
const ICONS: Dictionary[MapNodeView.Look, String] = {
	MapNodeView.Look.LOW: "icons/node_low",
	MapNodeView.Look.HIGH: "icons/node_high",
	MapNodeView.Look.SHOP: "icons/node_shop",
	MapNodeView.Look.DECK: "icons/node_deck",
}
const ON_WALK: Array[MapNodeView.Status] = [
	MapNodeView.Status.CURRENT, MapNodeView.Status.VISITED,
]

var _nodes: Array[MapNodeView] = []
var _scroll: ScrollContainer
var _canvas: Control


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	var caption: Label = UiKit.label(
		"ENTRY → QUOTA CHECK · ONE ROW AT A TIME", Fonts.Face.LABEL, 11, Color(Palette.GOLD, 0.7)
	)
	caption.position = Vector2(0.0, 6.0)
	caption.size = Vector2(SIZE.x, 14.0)
	add_child(caption)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(2.0, 0.0)
	_scroll.size = Vector2(SIZE.x - 4.0, CANVAS_HEIGHT)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.draw.connect(_draw_canvas)
	_scroll.add_child(_canvas)
	add_child(_legend())


func _draw() -> void:
	draw_style_box(UiKit.panel(), Rect2(Vector2.ZERO, size))


## Shows the nodes, and slides the map so focus_row is in view.
func show_nodes(nodes: Array[MapNodeView], rows: int, focus_row: int) -> void:
	_nodes = nodes
	for child: Node in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_canvas.custom_minimum_size = Vector2(FIRST.x * 2.0 + ROW_STEP * (rows - 1), CANVAS_HEIGHT)
	for view: MapNodeView in nodes:
		_add_node(view)
	_canvas.queue_redraw()
	var target: float = FIRST.x + ROW_STEP * focus_row - _scroll.size.x / 2.0
	_scroll.set_deferred("scroll_horizontal", roundi(maxf(target, 0.0)))


func _centre(row: int, lane: int) -> Vector2:
	return FIRST + Vector2(ROW_STEP * row, LANE_STEP * lane)


func _add_node(view: MapNodeView) -> void:
	var at: Vector2 = _centre(view.row, view.lane)
	var faded: float = _opacity(view.status)
	var button: Button = _node_button(view)
	button.position = at - Vector2(NODE, NODE) / 2.0
	button.modulate.a = faded
	button.pressed.connect(picked.emit.bind(view.row, view.lane))
	_canvas.add_child(button)
	var tag: Label = UiKit.label(view.tag, Fonts.Face.NUMBER, 11, _ink(view.status))
	tag.position = at + Vector2(-32.0, 25.0)
	tag.size = Vector2(64.0, 14.0)
	tag.modulate.a = faded
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(tag)
	if view.watched:
		var badge: PanelContainer = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UiKit.filled(Palette.ALERT, 11))
		badge.position = at + Vector2(14.0, -36.0)
		badge.custom_minimum_size = Vector2(22.0, 22.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var eye: TextureRect = Icons.rect("icons/eye", 14.0, Palette.CHIP_INK)
		eye.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.add_child(eye)
		_canvas.add_child(badge)
	if view.status == MapNodeView.Status.CURRENT:
		var you: Label = UiKit.chip("YOU", Palette.CREAM, Palette.PANEL, 11)
		you.position = at + Vector2(-20.0, -44.0)
		you.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(you)


## A node as a rounded square in its status's colours, with its kind's icon.
func _node_button(view: MapNodeView) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(NODE, NODE)
	button.size = Vector2(NODE, NODE)
	button.icon = Icons.of(ICONS[view.look])
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	var box: StyleBoxFlat = UiKit.filled(Palette.PANEL, 16)
	box.set_content_margin_all(11)
	box.set_border_width_all(2)
	box.border_color = Palette.DIM_EDGE
	var ink: Color = Palette.MUTED
	match view.status:
		MapNodeView.Status.CURRENT:
			box.bg_color = Palette.GOLD
			box.border_color = Palette.GOLD_EDGE
			box.set_border_width_all(0)
			box.border_width_bottom = 3
			ink = Palette.PANEL
		MapNodeView.Status.VISITED:
			box.bg_color = Palette.BUTTON
			box.border_color = Color(Palette.GOLD, 0.5)
			ink = Palette.GOLD
		MapNodeView.Status.REACHABLE:
			box.border_color = Palette.GOLD
			ink = Palette.CREAM
		MapNodeView.Status.AHEAD:
			box.border_color = Palette.OUTLINE
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		button.add_theme_color_override(colour, ink)
	return button


func _ink(status: MapNodeView.Status) -> Color:
	match status:
		MapNodeView.Status.CURRENT, MapNodeView.Status.VISITED:
			return Palette.GOLD
		MapNodeView.Status.REACHABLE:
			return Palette.CREAM
	return Palette.MUTED


func _opacity(status: MapNodeView.Status) -> float:
	match status:
		MapNodeView.Status.PAST:
			return 0.4
		MapNodeView.Status.VISITED:
			return 0.8
		MapNodeView.Status.AHEAD:
			return 0.9
	return 1.0


func _find(row: int, lane: int) -> MapNodeView:
	for view: MapNodeView in _nodes:
		if view.row == row and view.lane == lane:
			return view
	return null


## The links, under the nodes: the walk in solid gold, the next step dashed,
## the rest faint. Then a ring round a watched node and the picked one.
func _draw_canvas() -> void:
	for view: MapNodeView in _nodes:
		for lane: int in view.next_lanes:
			var to: MapNodeView = _find(view.row + 1, lane)
			if to != null:
				_draw_link(view, to)
	for view: MapNodeView in _nodes:
		var at: Vector2 = _centre(view.row, view.lane)
		if view.watched:
			_ring(Rect2(at - Vector2(30.0, 30.0), Vector2(60.0, 60.0)), 20, Palette.ALERT, 2)
		if view.selected:
			_ring(Rect2(at - Vector2(29.0, 29.0), Vector2(58.0, 58.0)), 21, Palette.CREAM, 3)


func _draw_link(from: MapNodeView, to: MapNodeView) -> void:
	var a: Vector2 = _centre(from.row, from.lane)
	var b: Vector2 = _centre(to.row, to.lane)
	if from.status in ON_WALK and to.status in ON_WALK:
		_canvas.draw_line(a, b, Palette.GOLD, 4.0, true)
	elif from.status == MapNodeView.Status.CURRENT and to.status == MapNodeView.Status.REACHABLE:
		_canvas.draw_dashed_line(a, b, Palette.GOLD, 2.0, 5.0, true, true)
	else:
		var off: bool = MapNodeView.Status.PAST in [from.status, to.status]
		_canvas.draw_line(a, b, Color(Palette.OUTLINE, 0.35 if off else 0.9), 2.0, true)


func _ring(rect: Rect2, radius: int, ink: Color, width: int) -> void:
	var box: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, radius)
	box.draw_center = false
	box.set_border_width_all(width)
	box.border_color = ink
	_canvas.draw_style_box(box, rect)


func _legend() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(0.0, SIZE.y - 28.0)
	row.size = Vector2(SIZE.x, 16.0)
	var walked: ColorRect = ColorRect.new()
	walked.color = Palette.GOLD
	walked.custom_minimum_size = Vector2(14.0, 4.0)
	walked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_legend_item(walked, "Walked"))
	var next: ColorRect = ColorRect.new()
	next.color = Color(Palette.GOLD, 0.6)
	next.custom_minimum_size = Vector2(14.0, 2.0)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_legend_item(next, "Next"))
	row.add_child(_legend_item(Icons.rect("icons/node_low", 13.0, Palette.MUTED), "Low stakes"))
	row.add_child(_legend_item(Icons.rect("icons/node_high", 13.0, Palette.MUTED), "High stakes"))
	row.add_child(_legend_item(Icons.rect("icons/eye", 13.0, Palette.ALERT), "Pit boss"))
	return row


func _legend_item(mark: Control, text: String) -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 4)
	item.add_child(mark)
	item.add_child(UiKit.label(text, Fonts.Face.LABEL, 11, Palette.MUTED))
	return item
