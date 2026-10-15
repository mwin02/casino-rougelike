class_name ShopScreen
extends Control
## The mid-floor shop (block U4), to the "Back room · mid-floor shop"
## artboard: the shelf of items and consumables and extra hands on the left;
## the bankroll against the quota with the picked item's cost, and the
## kit's slots, on the right. Draws a ShopVM and forwards presses.

## The run has moved to another screen.
signal moved

const SHELF: Rect2 = Rect2(44.0, 64.0, 506.0, 314.0)
const SIDE_X: float = 562.0
const SIDE_WIDTH: float = 238.0

var _vm: ShopVM
var _frame: DesignFrame
var _items: HBoxContainer
var _consumables: HBoxContainer
var _hands_text: Label
var _hands_buy: Button
var _amount: Label
var _bar: ShareBar
var _quota: Label
var _gap: Label
var _preview_title: Label
var _preview_bankroll: Label
var _preview_gap: Label
var _note: Label
var _slots: SlotsPanel
var _clock: Label


func _init(vm: ShopVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new(218.0, false))
	_build_title()
	var back: Button = UiKit.button("Back to map", true, 16)
	back.icon = Icons.of("ui/icon_back")
	back.add_theme_constant_override("icon_max_width", 16)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		back.add_theme_color_override(colour, Palette.PANEL)
	back.custom_minimum_size.y = 44.0
	back.position = Vector2(646.0, 9.0)
	back.pressed.connect(_on_leave)
	_frame.add_child(back)
	_build_shelf()
	_build_money()
	_slots = SlotsPanel.new(Vector2(SIDE_WIDTH, 132.0))
	_slots.position = Vector2(SIDE_X, 246.0)
	_frame.add_child(_slots)
	_refresh()


func _build_title() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 3
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(SHELF.position.x, 10.0)
	panel.custom_minimum_size = Vector2(330.0, 44.0)
	panel.rotation_degrees = -1.5
	_frame.add_child(panel)
	_frame.add_child(UiKit.tape(Vector2(170.0, 4.0), Vector2(46.0, 14.0), -4.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(Icons.rect("icons/node_shop", 22.0, Palette.GOLD))
	var names: VBoxContainer = _stack(-4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	names.add_child(_left(UiKit.label("Back-room shop", Fonts.Face.TITLE, 19, Palette.CREAM)))
	names.add_child(_left(UiKit.label(_vm.prices_text(), Fonts.Face.LABEL, 10, Palette.MUTED)))
	var clock: VBoxContainer = _stack(-4)
	row.add_child(clock)
	_clock = UiKit.label("", Fonts.Face.NUMBER, 16, Palette.CREAM)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_child(_clock)
	var free: Label = UiKit.label("THIS STOP COSTS NO HANDS", Fonts.Face.LABEL, 10, Palette.WIN)
	free.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_child(free)


func _build_shelf() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = SHELF.position
	panel.custom_minimum_size = SHELF.size
	panel.size = SHELF.size
	_frame.add_child(panel)
	var column: VBoxContainer = UiKit.panel_column(panel, 9, 4)
	column.add_child(ShopCards.heading(
		"ITEMS YOU DON'T OWN", "One of each · buying needs a free slot"
	))
	_items = HBoxContainer.new()
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override("separation", 8)
	column.add_child(_items)
	column.add_child(ShopCards.heading(
		"CONSUMABLES", "Single use, spent on a manipulation made that hand"
	))
	_consumables = HBoxContainer.new()
	_consumables.add_theme_constant_override("separation", 8)
	column.add_child(_consumables)
	var hands: HBoxContainer = HBoxContainer.new()
	hands.add_theme_constant_override("separation", 8)
	column.add_child(hands)
	hands.add_child(Icons.rect("icons/clock", 16.0, Palette.MUTED))
	_hands_text = _left(UiKit.label("", Fonts.Face.BODY, 12, Palette.SOFT))
	_hands_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands.add_child(_hands_text)
	_hands_buy = UiKit.button("", true, 13)
	_hands_buy.custom_minimum_size = Vector2(120.0, 32.0)
	_hands_buy.pressed.connect(_on_buy_hand)
	hands.add_child(_hands_buy)


## The bankroll against the quota, and what the picked item would do to it.
func _build_money() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(SIDE_X, SHELF.position.y)
	panel.custom_minimum_size = Vector2(SIDE_WIDTH, 172.0)
	_frame.add_child(panel)
	_frame.add_child(UiKit.tape(Vector2(SIDE_X + 96.0, 56.0), Vector2(48.0, 15.0), 3.0))
	var column: VBoxContainer = UiKit.panel_column(panel, 10, 2)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = _left(UiKit.label("BANKROLL", Fonts.Face.LABEL, 11, Palette.MUTED))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	_amount = UiKit.label("", Fonts.Face.NUMBER, 24, Palette.CREAM)
	top.add_child(_amount)
	_bar = ShareBar.new(Vector2(0.0, 12.0), Palette.GOLD)
	column.add_child(_bar)
	var foot: HBoxContainer = HBoxContainer.new()
	column.add_child(foot)
	_quota = _left(UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED))
	_quota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_quota)
	_gap = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.TIERS[2])
	foot.add_child(_gap)
	_preview_title = _left(UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED))
	column.add_child(_preview_title)
	_preview_bankroll = _preview_row(column, "Bankroll after")
	_preview_gap = _preview_row(column, "Short of quota")
	_preview_gap.add_theme_color_override("font_color", Palette.TIERS[2])
	_note = _left(UiKit.label("", Fonts.Face.BODY, 10, Palette.MUTED))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_note.add_theme_constant_override("line_spacing", -2)
	column.add_child(_note)


## A "Bankroll after ...... $82,500" line; returns its value label.
func _preview_row(column: VBoxContainer, caption: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var name: Label = _left(UiKit.label(caption, Fonts.Face.BODY, 12, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var value: Label = UiKit.label("", Fonts.Face.NUMBER, 16, Palette.CREAM)
	row.add_child(value)
	return value


func _refresh() -> void:
	UiKit.clear(_items)
	for row: ShopItemRow in _vm.items():
		_items.add_child(ShopCards.item(row, _on_pick, _on_buy_item))
	if _vm.items().is_empty():
		_items.add_child(UiKit.label("Nothing left on the shelf.", Fonts.Face.BODY, 12, Palette.MUTED))
	UiKit.clear(_consumables)
	for row: ConsumableRow in _vm.consumables():
		_consumables.add_child(ShopCards.consumable(row, _on_buy_consumable))
	_clock.text = _vm.hud().hands_left_text()
	var hands: ShopHands = _vm.hands()
	_hands_text.text = " · ".join(
		[hands.title, hands.text()].filter(func(part: String) -> bool: return not part.is_empty())
	)
	_hands_buy.text = "+1  %s" % hands.price_text if hands.can_buy else hands.verb
	_hands_buy.disabled = not hands.can_buy
	var money: ShopMoney = _vm.money()
	_amount.text = money.bankroll_text()
	var shares: Vector2 = _vm.preview_shares()
	_bar.show_share(shares.x, shares.y)
	_quota.text = money.quota_text()
	_gap.text = money.gap_text()
	_gap.add_theme_color_override(
		"font_color", Palette.GOLD if money.at_quota() else Palette.TIERS[2]
	)
	_preview_title.text = _vm.preview_title()
	_preview_bankroll.text = _vm.preview_bankroll_text()
	_preview_gap.text = _vm.preview_gap_text()
	_note.text = money.note()
	var held: Array[ConsumableRow] = _vm.consumables()
	_slots.refresh(
		_vm.slots(), _vm.slots_text(), "TAPE %d · SEALS %d" % [held[0].held, held[1].held]
	)


func _stack(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	return column


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


## For scripts/shot: picks the item at this place on the shelf, buys it.
func _shot_pick(index: int) -> void:
	_on_pick(_vm.items()[index].info.kind)


func _shot_buy(index: int) -> void:
	_on_buy_item(_vm.items()[index].info.kind)


func _on_pick(item: ItemKind.Kind) -> void:
	_vm.pick(item)
	_refresh()


func _on_buy_item(item: ItemKind.Kind) -> void:
	_vm.buy_item(item)
	_refresh()


func _on_buy_consumable(kind: ConsumableRow.Kind) -> void:
	_vm.buy_consumable(kind)
	_refresh()


func _on_buy_hand() -> void:
	_vm.buy_hand()
	_refresh()


func _on_leave() -> void:
	_vm.leave()
	moved.emit()
