extends Control
## A dev screen that lays out the table's parts in every state, to check
## them against the design canvas: cards face up and down, marked, taped
## and dimmed, at the sizes the table uses, and the heat meter in each tier.

const WIDTHS: Array[float] = [72.0, 60.0, 52.0, 40.0]
## The deck screen's card width, then larger to see the detail.
const LOOK_WIDTHS: Array[float] = [44.0, 56.0, 64.0]

var _parts: Control
## A second page: each permanent change's look (spec §4.1).
var _looks: Control


func _ready() -> void:
	var ground: ColorRect = ColorRect.new()
	ground.color = Palette.FELT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var design: DesignFrame = DesignFrame.new()
	add_child(design)
	var frame: Control = Control.new()
	design.add_child(frame)
	_parts = frame
	_looks = Control.new()
	_looks.visible = false
	design.add_child(_looks)
	_build_looks()

	var cards: Array[CardView] = [
		_card("KH"), _card("7C", false, 0), _card("10S", false, -1, true),
		_card("AD", false, 1, true), _card("9S", true), _card("9S", true, 1),
		_card("3C", false, -1, true), _card("4D"),
	]
	cards[7].dimmed = true
	# Ids pick the tape's shapes: every pairing of the three.
	for i: int in cards.size():
		cards[i].id = [0, 1, 2, 4, 5, 6, 3, 7][i]
	var x: float = 132.0
	for view: CardView in cards:
		_place(frame, view, 72.0, Vector2(x, 30.0))
		x += 86.0
	x = 132.0
	for width: float in WIDTHS:
		var sized: CardView = _card("QS", false, 2, true)
		sized.id = WIDTHS.find(width)
		_place(frame, sized, width, Vector2(x, 150.0))
		x += width + 22.0
	for symbol: int in CardFace.MARKS.size():
		var view: CardView = _card("JH", symbol % 2 == 1, symbol, symbol == 4)
		view.id = symbol + 4
		_place(frame, view, 52.0, Vector2(132.0 + symbol * 70.0, 280.0))

	var rules: HeatRules = HeatRules.from_config(TuneConfig.load_default())
	var meters: Array[HeatMeterVM] = [
		HeatMeterVM.new(rules, 18.0, 0.0),
		HeatMeterVM.new(rules, 52.0, 0.0, 9.0),
		HeatMeterVM.new(rules, 104.0, 12.0, 38.0),
		HeatMeterVM.new(rules, 150.0, 0.0),
	]
	for i: int in meters.size():
		var meter: HeatMeter = HeatMeter.new()
		meter.position = Vector2(500.0 + i * 82.0, 150.0)
		frame.add_child(meter)
		meter.show_meter(meters[i])


## For scripts/shot: swaps the table's parts for the deck screen's looks.
func _show_looks() -> void:
	_parts.visible = false
	_looks.visible = true


## A row per width: plain, then added, reforged, sealed and inked, each
## unmarked and marked. Last, a changed card face down: its back shows
## only its mark.
func _build_looks() -> void:
	var y: float = 20.0
	for width: float in LOOK_WIDTHS:
		var x: float = 30.0
		for change: int in CardView.Change.size():
			for symbol: int in [Card.NO_SYMBOL, change]:
				var view: CardView = _card("8D" if change % 2 == 0 else "QC", false, symbol)
				view.change = change as CardView.Change
				_place(_looks, view, width, Vector2(x, y))
				x += width + 8.0
		var back: CardView = _card("QC", true, 1)
		back.change = CardView.Change.SEALED
		_place(_looks, back, width, Vector2(x, y))
		y += width * CardFace.ASPECT + 22.0


func _card(
	code: String, face_down: bool = false, symbol: int = -1, taped: bool = false
) -> CardView:
	var card: Card = Card.parse(code)
	card.symbol = symbol
	return CardView.new(card, face_down, taped)


func _place(frame: Control, view: CardView, width: float, at: Vector2) -> void:
	var face: CardFace = CardFace.new()
	frame.add_child(face)
	face.position = at
	face.show_card(view, width)
