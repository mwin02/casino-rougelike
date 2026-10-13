class_name DeckPanel
extends Control
## The deck screen (spec §4.4), over the table, to the design canvas's Deck
## view: a title card with the card count, the way back to the table, every
## card the player owns in four suit rows over a legend of the looks a
## changed card wears, and down the right the player's marks and the heat
## floor the deck gives every table (§4.2). Tapping a mark dims every card
## without it. Draws a DeckViewVM and forwards the marks' presses to it.

signal closed

## What each look in the legend under the cards is called, in the order
## they're drawn.
enum Look { ADDED, REFORGED, SEALED, INKED, TAPED }

const SHADE: Color = Color(Palette.NIGHT, 0.95)
const ICON_DECK: Texture2D = preload("res://assets/ui/icon_deck.svg")
const ICON_BACK: Texture2D = preload("res://assets/ui/icon_back.svg")
const ICON_FLAME: Texture2D = preload("res://assets/ui/icon_flame.svg")
const LOOK_NAMES: Array[String] = ["Added", "Reforged", "Cold Seal", "Permanent Ink", "Taped"]
const PANELS_TOP: float = 64.0
const PANELS_HEIGHT: float = 314.0
const GRID_WIDTH: float = 550.0
const GRID_PAD: float = 10.0
const CARD_WIDTH: float = 38.0
const ROW_GAP: float = 13.0
## Most a card moves along from the one before it; a longer row overlaps.
const CARD_STEP: float = 41.0
const SWATCH: float = 15.0
## A card the marks' filter leaves out: darkened, not see-through, so a
## row that overlaps shows no seams.
const DIMMED: Color = Color(0.4, 0.42, 0.5)

var _vm: DeckViewVM
var _count: Label
var _size_note: Label
var _note: Label
var _cards: Control
## The marks, drawn over every card so a row that overlaps hides none.
var _marks: Control
## Where each marked card's top right corner is, with its view.
var _marked: Array[CardView] = []
var _corners: Array[Vector2] = []
var _marks_caption: Label
var _legend: VBoxContainer
var _heat_floor: Label
var _close: Button


func _init() -> void:
	# Taps stop here, not at the table underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_title()
	var right: float = DesignFrame.SIZE.x - DesignFrame.GUTTER
	var close: Button = UiKit.button("Back to table", true, 16)
	for state: String in ["normal", "hover", "pressed"]:
		# Room on the left for the arrow.
		close.get_theme_stylebox(state).content_margin_left = 40
	close.custom_minimum_size.y = 44.0
	close.pressed.connect(closed.emit)
	add_child(close)
	_close = close
	var arrow: TextureRect = _icon(ICON_BACK, 18.0, Palette.PANEL)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.position = Vector2(16.0, 11.0)
	arrow.size = Vector2(18.0, 18.0)
	close.add_child(arrow)
	_note = UiKit.label("", Fonts.Face.BODY, 12, Palette.LOSS)
	_note.position = Vector2(DesignFrame.GUTTER + 314.0, 24.0)
	add_child(_note)
	var grid: Panel = Panel.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_stylebox_override("panel", UiKit.panel())
	grid.position = Vector2(DesignFrame.GUTTER, PANELS_TOP)
	grid.size = Vector2(GRID_WIDTH, PANELS_HEIGHT)
	add_child(grid)
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_build_looks(grid)
	_build_side(right)


## The title card, pinned up a touch askew under a strip of tape.
func _build_title() -> void:
	var card: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	card.add_theme_stylebox_override("panel", box)
	card.position = Vector2(DesignFrame.GUTTER, 10.0)
	card.custom_minimum_size = Vector2(300.0, 44.0)
	card.rotation_degrees = -1.5
	add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(_icon(ICON_DECK, 22.0, Palette.GOLD))
	var title: Label = UiKit.label("Your deck", Fonts.Face.TITLE, 19, Palette.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(title)
	var counts: VBoxContainer = VBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", -5)
	row.add_child(counts)
	_count = UiKit.label("", Fonts.Face.NUMBER, 19, Palette.CREAM)
	_size_note = UiKit.label("", Fonts.Face.LABEL, 10, Palette.MUTED)
	for label: Label in [_count, _size_note]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counts.add_child(label)
	var tape: ColorRect = ColorRect.new()
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.color = Color(Palette.GOLD, 0.55)
	tape.position = Vector2(150.0, 4.0)
	tape.size = Vector2(46.0, 14.0)
	tape.rotation_degrees = -4.0
	add_child(tape)


## The legend along the bottom of the cards' panel: each look and its name.
func _build_looks(grid: Panel) -> void:
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(Palette.GOLD, 0.14)
	rule.position = Vector2(GRID_PAD, PANELS_HEIGHT - 30.0)
	rule.size = Vector2(GRID_WIDTH - GRID_PAD * 2.0, 1.0)
	grid.add_child(rule)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.position = Vector2(GRID_PAD + 4.0, PANELS_HEIGHT - 24.0)
	grid.add_child(row)
	for look: Look in Look.values():
		var swatch: Control = Control.new()
		swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.draw.connect(_draw_swatch.bind(swatch, look))
		row.add_child(swatch)
		var name: Label = UiKit.label(LOOK_NAMES[look], Fonts.Face.LABEL, 12, Palette.MUTED)
		name.custom_minimum_size.x = name.get_minimum_size().x + 9.0
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name)


## The right-hand panel: the marks, then the heat floor at the bottom.
func _build_side(right: float) -> void:
	var left: float = DesignFrame.GUTTER + GRID_WIDTH + 10.0
	var side: PanelContainer = PanelContainer.new()
	side.position = Vector2(left, PANELS_TOP)
	side.custom_minimum_size = Vector2(right - left, PANELS_HEIGHT)
	add_child(side)
	var column: VBoxContainer = UiKit.panel_column(side, 10, 6)
	_marks_caption = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_marks_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_marks_caption)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 6)
	_legend.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_legend)
	var floor_box: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET, 11)
	box.set_border_width_all(1)
	box.border_color = Color(Palette.GOLD, 0.35)
	box.set_content_margin_all(7)
	floor_box.add_theme_stylebox_override("panel", box)
	column.add_child(floor_box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	floor_box.add_child(row)
	row.add_child(_icon(ICON_FLAME, 22.0, Palette.GOLD))
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var heading: Label = UiKit.label("Heat floor", Fonts.Face.BUTTON, 15, Palette.CREAM)
	var note: Label = UiKit.label("Tables start here", Fonts.Face.BODY, 10, Palette.MUTED)
	for label: Label in [heading, note]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(label)
	_heat_floor = UiKit.chip("", Palette.GOLD, Palette.PANEL, 22)
	_heat_floor.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
	_heat_floor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_heat_floor)


func open(vm: DeckViewVM) -> void:
	_vm = vm
	visible = true
	_refresh()


func _refresh() -> void:
	_count.text = _vm.count_text()
	_size_note.text = _vm.size_note()
	_note.text = _vm.house_deck_note()
	_marks_caption.text = _vm.marks_caption()
	_heat_floor.text = _vm.heat_floor_text()
	# Its width is only known once it's on screen.
	_close.reset_size()
	_close.position = Vector2(DesignFrame.SIZE.x - DesignFrame.GUTTER - _close.size.x, 9.0)
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_marked.clear()
	_corners.clear()
	var left: float = DesignFrame.GUTTER + GRID_PAD
	var room: float = GRID_WIDTH - GRID_PAD * 2.0
	var y: float = PANELS_TOP + 14.0
	for suit: Card.Suit in Card.Suit.values():
		var row: Array[CardView] = _vm.row(suit)
		var step: float = CARD_STEP
		if row.size() > 1:
			step = minf(step, (room - CARD_WIDTH) / (row.size() - 1))
		for i: int in row.size():
			var face: CardFace = CardFace.new()
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.draws_mark = false
			_cards.add_child(face)
			face.position = Vector2(left + i * step, y)
			face.show_card(row[i], CARD_WIDTH)
			if row[i].dimmed:
				face.modulate = DIMMED
			if row[i].is_marked():
				_marked.append(row[i])
				_corners.append(face.position + Vector2(CARD_WIDTH, 0.0))
		y += roundf(CARD_WIDTH * CardFace.ASPECT) + ROW_GAP
	_marks.queue_redraw()
	UiKit.clear(_legend)
	for entry: LegendRow in _vm.legend():
		var row: Button = UiKit.option("%s  ·  %d" % [entry.name, entry.count], entry.chosen)
		row.icon = CardFace.MARKS[entry.symbol % CardFace.MARKS.size()]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_constant_override("icon_max_width", 16)
		var ink: Color = Palette.PANEL if entry.chosen else Palette.GOLD
		for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			row.add_theme_color_override(colour, ink)
		row.pressed.connect(_on_symbol.bind(entry.symbol))
		_legend.add_child(row)


func _on_symbol(symbol: int) -> void:
	_vm.toggle_filter(symbol)
	_refresh()


## A line icon at this size, in one colour.
func _icon(texture: Texture2D, side: float, color: Color) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	return icon


func _draw_marks() -> void:
	for i: int in _marked.size():
		var alpha: float = CardFace.DIM_ALPHA if _marked[i].dimmed else 1.0
		CardFace.draw_mark_on(_marks, _corners[i], CARD_WIDTH, _marked[i].symbol, alpha)


## A look in small, as CardFace draws it on a card.
func _draw_swatch(swatch: Control, look: Look) -> void:
	var centre: Vector2 = Vector2(SWATCH, SWATCH) / 2.0
	var half: float = SWATCH / 2.0
	var card: Rect2 = Rect2(2.0, 0.0, SWATCH - 4.0, SWATCH)
	match look:
		Look.ADDED:
			swatch.draw_circle(centre, half, Palette.ADDED, true, -1.0, true)
			var arm: Vector2 = Vector2(half * 0.55, 0.0)
			swatch.draw_line(centre - arm, centre + arm, Palette.CREAM, 2.0, true)
			arm = Vector2(0.0, half * 0.55)
			swatch.draw_line(centre - arm, centre + arm, Palette.CREAM, 2.0, true)
		Look.REFORGED:
			var foil: StyleBoxFlat = UiKit.filled(Palette.CREAM, 2)
			foil.set_border_width_all(2)
			foil.border_color = Palette.GOLD
			swatch.draw_style_box(foil, card)
		Look.SEALED:
			swatch.draw_circle(centre, half, Palette.SEAL.darkened(0.3), true, -1.0, true)
			swatch.draw_circle(centre, half * 0.8, Palette.SEAL, true, -1.0, true)
			for spoke: int in 3:
				var ray: Vector2 = Vector2.from_angle(spoke * PI / 3.0) * half * 0.55
				swatch.draw_line(centre - ray, centre + ray, Palette.CREAM, 1.0, true)
		Look.INKED:
			swatch.draw_style_box(UiKit.filled(Palette.CREAM, 2), card)
			swatch.draw_line(Vector2(4.0, 5.0), Vector2(8.0, 4.0), Palette.MARKER, 2.0, true)
			swatch.draw_line(Vector2(4.0, 9.0), Vector2(10.0, 7.5), Palette.MARKER, 2.0, true)
		Look.TAPED:
			swatch.draw_style_box(UiKit.filled(Palette.CREAM, 2), card)
			swatch.draw_set_transform(centre, -0.4)
			swatch.draw_rect(Rect2(-half - 1.0, -3.0, SWATCH + 2.0, 6.0), Palette.TAPE)
			swatch.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -2000.0, 4000.0 + size.x, 4000.0 + size.y), SHADE)
