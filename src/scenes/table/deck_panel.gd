class_name DeckPanel
extends Control
## The deck screen (spec §4.4), over the table: every card the player owns
## in four suit rows, each wearing its mark, tape or change, with the card
## count above and the marks' legend down the right. Tapping a symbol in the
## legend dims every card without it. Draws a DeckViewVM and forwards the
## legend's presses to it.

signal closed

const SHADE: Color = Color(Palette.NIGHT, 0.95)
const CARD_WIDTH: float = 44.0
const ROWS_TOP: float = 60.0
const ROW_GAP: float = 9.0
## Most a card moves along from the one before it; a longer row overlaps.
const CARD_STEP: float = 47.0
const LEGEND_WIDTH: float = 128.0
## A card the legend's filter leaves out: darkened, not see-through, so a
## row that overlaps shows no seams.
const DIMMED: Color = Color(0.4, 0.42, 0.5)

var _vm: DeckViewVM
var _count: Label
var _note: Label
var _cards: Control
## The marks, drawn over every card so a row that overlaps hides none.
var _marks: Control
## Where each marked card's top right corner is, with its view.
var _marked: Array[CardView] = []
var _corners: Array[Vector2] = []
var _legend: VBoxContainer


func _init() -> void:
	# Taps stop here, not at the table underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title: Label = UiKit.label("Your deck", Fonts.Face.TITLE, 19, Palette.CREAM)
	title.position = Vector2(DesignFrame.GUTTER, 14.0)
	add_child(title)
	_count = UiKit.label("", Fonts.Face.NUMBER, 17, Palette.GOLD)
	_count.position = Vector2(DesignFrame.GUTTER + 108.0, 17.0)
	add_child(_count)
	_note = UiKit.label("", Fonts.Face.BODY, 12, Palette.LOSS)
	_note.position = Vector2(DesignFrame.GUTTER + 196.0, 20.0)
	add_child(_note)
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	var right: float = DesignFrame.SIZE.x - DesignFrame.GUTTER
	var close: Button = UiKit.button("Back to table", false, 13)
	close.pressed.connect(closed.emit)
	add_child(close)
	close.reset_size()
	close.position = Vector2(right - close.size.x, 12.0)
	var side: PanelContainer = PanelContainer.new()
	side.position = Vector2(right - LEGEND_WIDTH, ROWS_TOP)
	side.custom_minimum_size.x = LEGEND_WIDTH
	add_child(side)
	_legend = UiKit.panel_column(side, 10, 6)


func open(vm: DeckViewVM) -> void:
	_vm = vm
	visible = true
	_refresh()


func _refresh() -> void:
	_count.text = _vm.count_text().to_upper()
	_note.text = _vm.house_deck_note()
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_marked.clear()
	_corners.clear()
	var left: float = DesignFrame.GUTTER
	var room: float = DesignFrame.SIZE.x - DesignFrame.GUTTER * 2.0 - LEGEND_WIDTH - 18.0
	var y: float = ROWS_TOP
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
	var caption: Label = UiKit.label("MARKS", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_legend.add_child(caption)
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


func _draw_marks() -> void:
	for i: int in _marked.size():
		var alpha: float = CardFace.DIM_ALPHA if _marked[i].dimmed else 1.0
		CardFace.draw_mark_on(_marks, _corners[i], CARD_WIDTH, _marked[i].symbol, alpha)


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -2000.0, 4000.0 + size.x, 4000.0 + size.y), SHADE)
