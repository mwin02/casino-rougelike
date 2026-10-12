extends Control
## A dev screen that lays out the table's parts in every state, to check
## them against the design canvas: cards face up and down, marked, taped
## and dimmed, at the sizes the table uses, and the heat meter in each tier.

const WIDTHS: Array[float] = [72.0, 60.0, 52.0, 40.0]


func _ready() -> void:
	var ground: ColorRect = ColorRect.new()
	ground.color = Palette.FELT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var frame: DesignFrame = DesignFrame.new()
	add_child(frame)

	var cards: Array[CardView] = [
		_card("KH"), _card("7C", false, 0), _card("10S", false, -1, true),
		_card("AD", false, 1, true), _card("9S", true), _card("9S", true, 1),
		_card("9S", true, -1, true), _card("4D"),
	]
	cards[7].dimmed = true
	var x: float = 132.0
	for view: CardView in cards:
		_place(frame, view, 72.0, Vector2(x, 30.0))
		x += 86.0
	x = 132.0
	for width: float in WIDTHS:
		_place(frame, _card("QS", false, 2, true), width, Vector2(x, 150.0))
		x += width + 22.0
	for symbol: int in CardFace.MARKS.size():
		var view: CardView = _card("JH", symbol % 2 == 1, symbol, symbol > 2)
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
