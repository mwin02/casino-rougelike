class_name OffersScreen
extends Control
## A node's table offers (block U4), to the "Table node" artboard: a card
## for each table with its game, stakes and house rule, the pit boss's eye
## on a watched one, and a Sit button; Back to map leaves the node. Draws an
## OffersVM and forwards presses.

## The run has moved to another screen.
signal moved

const AREA: Rect2 = Rect2(44.0, 86.0, 756.0, 242.0)
const GAP: float = 12.0
## A third of the area: three tables fit; two keep the same width.
const CARD_WIDTH: float = 244.0
## The cards drawn on each game's little felt: codes, and which lie face down.
const FELT_CARDS: Dictionary[GameKind.Kind, Array] = {
	GameKind.Kind.BLACKJACK: ["9C", "KH"],
	GameKind.Kind.BACCARAT: ["4D", "QS"],
	GameKind.Kind.HIGH_LOW: ["7S", "AS"],
}
const FACE_DOWN: Dictionary[GameKind.Kind, bool] = {
	GameKind.Kind.BLACKJACK: true,
	GameKind.Kind.BACCARAT: false,
	GameKind.Kind.HIGH_LOW: true,
}

var _vm: OffersVM
var _frame: DesignFrame


func _init(vm: OffersVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new(70.0))
	var hud: FloorHudVM = vm.hud()
	var clock: ClockPanel = ClockPanel.new()
	clock.position = Vector2(DesignFrame.GUTTER, 9.0)
	clock.refresh(hud)
	_frame.add_child(clock)
	var right: float = DesignFrame.SIZE.x - DesignFrame.GUTTER
	var bankroll: BankrollPanel = BankrollPanel.new()
	bankroll.position = Vector2(right - BankrollPanel.WIDTH, 9.0)
	bankroll.refresh(hud)
	_frame.add_child(bankroll)
	_frame.add_child(UiKit.tape(Vector2(right - 146.0, 3.0), Vector2(40.0, 13.0), -4.0))
	_frame.add_child(_heat_panel(hud))
	_frame.add_child(_title())
	var offers: Array[TableOffer] = vm.offers()
	var width: float = offers.size() * CARD_WIDTH + (offers.size() - 1) * GAP
	var x: float = AREA.position.x + (AREA.size.x - width) / 2.0
	for offer: TableOffer in offers:
		var card: PanelContainer = _card(offer)
		card.position = Vector2(x, AREA.position.y)
		_frame.add_child(card)
		if offer.watched:
			_frame.add_child(_watching_tag(Vector2(x + CARD_WIDTH - 148.0, AREA.position.y - 11.0)))
		else:
			_frame.add_child(
				UiKit.tape(Vector2(x + 92.0, AREA.position.y - 8.0), Vector2(46.0, 15.0), -3.0)
			)
		x += CARD_WIDTH + GAP
	var back: Button = UiKit.button("Back to map", false, 16)
	back.icon = Icons.of("ui/icon_back")
	back.add_theme_constant_override("icon_max_width", 16)
	back.custom_minimum_size.y = 44.0
	back.position = Vector2(DesignFrame.GUTTER, 334.0)
	back.pressed.connect(_on_back)
	_frame.add_child(back)
	var note: Label = UiKit.label(OffersVM.FOOT_NOTE, Fonts.Face.BODY, 12, Palette.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.position = Vector2(236.0, 334.0)
	note.size = Vector2(right - 236.0, 44.0)
	_frame.add_child(note)


## Run heat in a line, between the clock and the node's title.
func _heat_panel(hud: FloorHudVM) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(252.0, 12.0)
	panel.custom_minimum_size.x = 104.0
	panel.rotation_degrees = 1.0
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = UiKit.label("RUN HEAT", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	top.add_child(UiKit.label(hud.run_heat_text(), Fonts.Face.NUMBER, 19, Palette.CREAM))
	var bar: ShareBar = ShareBar.new(Vector2(0.0, 8.0), Palette.RUN_HEAT)
	bar.show_share(hud.run_heat_share())
	column.add_child(bar)
	if hud.pit_boss():
		var boss: Label = UiKit.chip("Pit boss", Palette.ALERT, Palette.CHIP_INK, 11)
		boss.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(boss)
	return panel


## "High stakes" over the row, in the middle of the header.
func _title() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.position = Vector2(372.0, 12.0)
	column.custom_minimum_size.x = 204.0
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	column.add_child(row)
	var badge: PanelContainer = PanelContainer.new()
	var gold: StyleBoxFlat = UiKit.filled(Palette.GOLD, 10)
	gold.set_content_margin_all(5)
	gold.border_color = Palette.GOLD_EDGE
	gold.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", gold)
	var icon: String = "icons/node_high" if _vm.is_high_stakes() else "icons/node_low"
	badge.add_child(Icons.rect(icon, 20.0, Palette.PANEL))
	row.add_child(badge)
	row.add_child(UiKit.label(_vm.title(), Fonts.Face.TITLE, 20, Palette.CREAM))
	column.add_child(UiKit.label(_vm.row_text(), Fonts.Face.LABEL, 11, Palette.MUTED))
	return column


func _card(offer: TableOffer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel()
	box.set_content_margin_all(10)
	if offer.watched:
		box.set_border_width_all(2)
		box.border_color = Palette.ALERT
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(CARD_WIDTH, AREA.size.y)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	column.add_child(_felt(offer))
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	column.add_child(head)
	head.add_child(Icons.rect(NodePanel.GAME_ICONS[offer.game], 20.0, Palette.GOLD))
	var name: Label = UiKit.label(offer.name, Fonts.Face.TITLE, 18, Palette.CREAM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var tier: Label = UiKit.chip(
		_vm.tier_text(offer), Palette.TIERS[1 if offer.watched else 0], Palette.CHIP_INK
	)
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tier)
	var facts: HBoxContainer = HBoxContainer.new()
	facts.add_theme_constant_override("separation", 8)
	column.add_child(facts)
	facts.add_child(_fact("STAKES", offer.stakes_text, Fonts.Face.NUMBER, 16, Palette.CREAM))
	var has_rule: bool = offer.rule_text != TableOffer.NO_RULE
	facts.add_child(_fact(
		"HOUSE RULE", offer.rule_text, Fonts.Face.BODY, 13,
		Palette.TEAL if has_rule else Palette.MUTED
	))
	column.add_child(_hidden(offer))
	var sit: Button = UiKit.button(_vm.sit_label(offer), true, 17)
	sit.custom_minimum_size.y = 44.0
	sit.disabled = not _vm.can_sit(offer)
	sit.pressed.connect(_on_sit.bind(offer))
	column.add_child(sit)
	return panel


## The table's little felt: a strip of baize in a wooden rail with two of
## the game's cards on it, tinted where the pit boss watches.
func _felt(offer: TableOffer) -> PanelContainer:
	var felt: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Palette.FELT, 10)
	box.set_border_width_all(3)
	box.border_color = Palette.RAIL
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	if offer.watched:
		box.bg_color = Palette.FELT.lerp(Palette.ALERT, 0.12)
	felt.add_theme_stylebox_override("panel", box)
	felt.clip_contents = true
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6 if FACE_DOWN[offer.game] else 14)
	felt.add_child(row)
	var codes: Array = FELT_CARDS[offer.game]
	for i: int in codes.size():
		var code: String = codes[i]
		var down: bool = i == codes.size() - 1 and FACE_DOWN[offer.game]
		var face: CardFace = CardFace.new()
		face.show_card(CardView.new(Card.parse(code), down, false), 22.0)
		row.add_child(face)
	return felt


func _fact(caption: String, value: String, face: Fonts.Face, size: int, ink: Color) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", -3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: Label = UiKit.label(caption, Fonts.Face.LABEL, 10, Palette.MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(head)
	var body: Label = UiKit.label(value, face, size, ink)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.clip_text = true
	column.add_child(body)
	return column


## "Cost rolls hidden", and what is known without them.
func _hidden(offer: TableOffer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 10)
	box.draw_center = false
	box.set_border_width_all(2)
	box.border_color = Palette.DIM_EDGE
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 4
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	column.add_child(head)
	head.add_child(Icons.rect("icons/lock", 13.0, Palette.MUTED))
	head.add_child(UiKit.label(OffersVM.HIDDEN, Fonts.Face.BODY, 11, Palette.MUTED))
	var note: Label = UiKit.label(_vm.hidden_note(offer), Fonts.Face.BODY, 11, Palette.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_constant_override("line_spacing", -2)
	column.add_child(note)
	return panel


func _watching_tag(at: Vector2) -> Label:
	var tag: Label = UiKit.chip("PIT BOSS WATCHING", Palette.ALERT, Palette.CHIP_INK)
	tag.position = at
	return tag


## For scripts/shot: sits at the table at this place.
func _sit(index: int) -> void:
	_on_sit(_vm.offers()[index])


func _on_sit(offer: TableOffer) -> void:
	_vm.sit(offer)
	moved.emit()


func _on_back() -> void:
	_vm.back()
	moved.emit()
