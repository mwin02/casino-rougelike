class_name ShopCards
extends RefCounted
## The cards on a shop's shelf, to the design canvas, shared by the
## mid-floor shop and the end shop: an item with its rarity, effect and Buy
## button, and a consumable with its stock.

## Common, uncommon, rare.
const RARITY_INKS: Array[Color] = [Palette.MUTED, Palette.TEAL, Palette.GOLD]
const CONSUMABLE_ICONS: Dictionary[ConsumableRow.Kind, String] = {
	ConsumableRow.Kind.TAPE: "icons/tape",
	ConsumableRow.Kind.SEAL: "icons/seal",
}


## A card set into a panel; gold-edged when picked.
static func inset(picked: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET, 12)
	box.set_border_width_all(2 if picked else 1)
	box.border_color = Palette.GOLD if picked else Color(Palette.MUTED, 0.15)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	return box


## A gold Buy button reading "Buy $14,000", or why it can't be bought.
static func buy_button(verb: String, price_text: String, can_buy: bool) -> Button:
	var text: String = "%s  %s" % [verb, price_text] if can_buy else verb
	var button: Button = UiKit.button(text, true, 14)
	button.custom_minimum_size.y = 38.0
	button.disabled = not can_buy
	return button


## An item's card. on_pick runs when the card is tapped, on_buy on Buy;
## both get the item's kind. Without preview, as at the end shop, the card
## isn't picked and shows no gap to the quota.
static func item(
	row: ShopItemRow, on_pick: Callable, on_buy: Callable, preview: bool = true
) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", inset(row.picked and preview))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 10.0
	card.clip_contents = true
	if preview:
		card.gui_input.connect(_on_card_input.bind(on_pick, row.info.kind))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var rarity: Label = UiKit.chip(
		row.info.rarity_text, RARITY_INKS[row.info.rarity], Palette.CHIP_INK, 11
	)
	rarity.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(rarity)
	var build: Label = UiKit.label(row.info.archetype, Fonts.Face.LABEL, 10, Palette.MUTED)
	build.clip_text = true
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(build)
	var name: Label = _left(UiKit.label(row.info.name, Fonts.Face.BUTTON, 15, Palette.CREAM))
	name.clip_text = true
	column.add_child(name)
	var effect: Label = _left(UiKit.label(row.info.effect, Fonts.Face.BODY, 11, Palette.MUTED))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.add_theme_constant_override("line_spacing", -2)
	effect.clip_text = true
	column.add_child(effect)
	var gap: HBoxContainer = HBoxContainer.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.visible = preview
	column.add_child(gap)
	var caption: Label = _left(UiKit.label("GAP AFTER", Fonts.Face.LABEL, 11, Palette.MUTED))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.add_child(caption)
	gap.add_child(UiKit.label(row.gap_after_text, Fonts.Face.NUMBER, 12, Palette.TIERS[2]))
	var buy: Button = buy_button(row.verb, row.price_text, row.can_buy)
	buy.pressed.connect(on_buy.bind(row.info.kind))
	column.add_child(buy)
	return card


## A consumable's card: its icon, name, effect and stock, and its price as
## the button. on_buy gets the consumable's kind.
static func consumable(row: ConsumableRow, on_buy: Callable) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", inset())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	card.add_child(line)
	card.custom_minimum_size.x = 10.0
	line.add_child(Icons.rect(CONSUMABLE_ICONS[row.kind], 22.0, Palette.TEAL))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	column.add_child(_left(UiKit.label(row.name, Fonts.Face.BUTTON, 14, Palette.CREAM)))
	var effect: Label = _left(UiKit.label(row.effect, Fonts.Face.BODY, 10, Palette.MUTED))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_constant_override("line_spacing", -3)
	column.add_child(effect)
	var stock: Label = _left(UiKit.label(
		"STOCK %s · HELD %d" % [row.stock_text, row.held], Fonts.Face.LABEL, 11, Palette.SOFT
	))
	stock.clip_text = true
	column.add_child(stock)
	var buy: Button = UiKit.button(row.price_text if row.can_buy else row.verb, true, 14)
	buy.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
	buy.custom_minimum_size = Vector2(72.0, 40.0)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = buy.get_theme_stylebox(state)
		box.content_margin_left = 6
		box.content_margin_right = 6
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not row.can_buy
	buy.pressed.connect(on_buy.bind(row.kind))
	line.add_child(buy)
	return card


## A small caption over a group, with a note at its right.
static func heading(caption: String, note: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_left(UiKit.label(caption, Fonts.Face.LABEL, 11, Palette.MUTED)))
	var right: Label = UiKit.label(note, Fonts.Face.BODY, 10, Palette.MUTED)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.clip_text = true
	row.add_child(right)
	return row


static func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _on_card_input(event: InputEvent, on_pick: Callable, kind: ItemKind.Kind) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (touch != null and touch.pressed) or (click != null and click.pressed):
		on_pick.call(kind)
