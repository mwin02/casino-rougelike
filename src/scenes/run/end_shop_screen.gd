class_name EndShopScreen
extends Control
## The end of a floor (block U4), to the "End of floor: quota check and
## shop" artboard: how the check went and the bankroll over its reserve
## along the top; the shop under tabs on the left, the kit's slots and the
## elevator on the right. A deck service being worked takes the shop's
## place. Draws an EndShopVM and forwards presses.

## The run has moved to another screen.
signal moved

const SHOP: Rect2 = Rect2(44.0, 86.0, 480.0, 290.0)
const SIDE_X: float = 580.0
const SIDE_WIDTH: float = 220.0

var _vm: EndShopVM
var _frame: DesignFrame
var _amount: Label
var _bar: ReserveBar
var _spend: Label
var _shop: PanelContainer
var _tabs: HBoxContainer
var _body: VBoxContainer
var _bench: ServicesBench
var _slots: SlotsPanel


func _init(vm: EndShopVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new(218.0, false))
	_build_check()
	_build_money()
	_build_shop()
	_slots = SlotsPanel.new(Vector2(SIDE_WIDTH, 226.0))
	_slots.position = Vector2(SIDE_X, SHOP.position.y)
	_frame.add_child(_slots)
	_frame.add_child(UiKit.tape(Vector2(SIDE_X + 86.0, 78.0), Vector2(48.0, 15.0), 3.0))
	_build_elevator()
	_bench = ServicesBench.new(vm.services())
	_bench.position = Vector2(SHOP.position.x, 66.0)
	_bench.changed.connect(_refresh)
	_frame.add_child(_bench)
	_refresh()


## How the quota check went: a slip taped along the top.
func _build_check() -> void:
	var check: QuotaStrip = _vm.check()
	var ink: Color = Palette.RUN_HEAT if check.short else Palette.WIN
	var panel: PanelContainer = _slip(Vector2(SHOP.position.x, 12.0), SHOP.size.x, -1.5)
	_frame.add_child(UiKit.tape(Vector2(250.0, 6.0), Vector2(46.0, 14.0), -4.0))
	var column: VBoxContainer = _stack(-1)
	panel.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	row.add_child(Icons.rect("icons/marker" if check.short else "icons/check", 20.0, ink))
	var names: VBoxContainer = _stack(-5)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	names.add_child(_left(UiKit.label(check.heading, Fonts.Face.LABEL, 10, Palette.MUTED)))
	names.add_child(_left(UiKit.label(check.title, Fonts.Face.TITLE, 17, Palette.CREAM)))
	var sums: VBoxContainer = _stack(-5)
	row.add_child(sums)
	var amounts: HBoxContainer = HBoxContainer.new()
	amounts.alignment = BoxContainer.ALIGNMENT_END
	sums.add_child(amounts)
	amounts.add_child(UiKit.label(check.bankroll_text, Fonts.Face.NUMBER, 16, Palette.CREAM))
	amounts.add_child(UiKit.label(check.quota_text, Fonts.Face.NUMBER, 12, Palette.MUTED))
	sums.add_child(UiKit.label("BANKROLL AT CHECK / QUOTA", Fonts.Face.LABEL, 9, Palette.MUTED))
	row.add_child(Icons.rect("icons/key_card", 18.0, Palette.GOLD))
	row.add_child(UiKit.label("KEY CARD", Fonts.Face.LABEL, 10, Palette.GOLD))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	column.add_child(line)
	line.add_child(UiKit.label(check.lead, Fonts.Face.BODY_HEAVY, 10, ink))
	var detail: Label = _left(UiKit.label("· " + check.detail, Fonts.Face.BODY, 10, Palette.MUTED))
	detail.clip_text = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(detail)


## The bankroll over its reserve, and what that leaves to spend.
func _build_money() -> void:
	var panel: PanelContainer = _slip(Vector2(SIDE_X, 12.0), SIDE_WIDTH, 1.0)
	var column: VBoxContainer = _stack(1)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = _left(UiKit.label("BANKROLL", Fonts.Face.LABEL, 10, Palette.MUTED))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	_amount = UiKit.label("", Fonts.Face.NUMBER, 20, Palette.CREAM)
	top.add_child(_amount)
	_bar = ReserveBar.new(8.0)
	column.add_child(_bar)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 3)
	column.add_child(foot)
	foot.add_child(Icons.rect("icons/lock", 11.0, Palette.LOSS))
	var reserve: Label = _left(
		UiKit.label(_vm.money().reserve_text(), Fonts.Face.BODY_HEAVY, 10, Palette.LOSS)
	)
	reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(reserve)
	_spend = UiKit.label("", Fonts.Face.NUMBER, 12, Palette.GOLD)
	foot.add_child(_spend)
	foot.add_child(UiKit.label("to spend", Fonts.Face.BODY, 10, Palette.MUTED))


func _build_shop() -> void:
	_shop = PanelContainer.new()
	_shop.position = SHOP.position
	_shop.custom_minimum_size = SHOP.size
	_shop.size = SHOP.size
	_frame.add_child(_shop)
	var column: VBoxContainer = UiKit.panel_column(_shop, 9, 6)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var names: VBoxContainer = _stack(-5)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_left(UiKit.label("End shop", Fonts.Face.TITLE, 17, Palette.CREAM)))
	names.add_child(
		_left(UiKit.label(_vm.shop().prices_text(), Fonts.Face.LABEL, 10, Palette.MUTED))
	)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	head.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)


func _build_elevator() -> void:
	var button: Button = UiKit.button("", true)
	button.position = Vector2(SIDE_X, 324.0)
	button.custom_minimum_size = Vector2(SIDE_WIDTH, 52.0)
	button.pressed.connect(_on_elevator)
	_frame.add_child(button)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0
	row.offset_right = -16.0
	row.offset_bottom = -4.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var words: VBoxContainer = _stack(-5)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(_left(UiKit.label(_vm.elevator_text(), Fonts.Face.BUTTON, 17, Palette.PANEL)))
	words.add_child(_left(UiKit.label(_vm.next_text(), Fonts.Face.LABEL, 10, Palette.PANEL)))
	row.add_child(Icons.rect("icons/elevator", 24.0, Palette.PANEL))


func _refresh() -> void:
	var money: ReserveMoney = _vm.money()
	_amount.text = money.bankroll_text()
	_bar.show_money(money)
	_spend.text = money.spend_text()
	UiKit.clear(_tabs)
	for tab: Choice in _vm.tabs():
		var button: Button = UiKit.option(tab.label, tab.selected, 12)
		button.pressed.connect(_on_tab.bind(tab.id))
		_tabs.add_child(button)
	UiKit.clear(_body)
	match _vm.tab:
		EndShopVM.Tab.ITEMS:
			_fill_items()
		EndShopVM.Tab.CONSUMABLES:
			_fill_consumables()
		EndShopVM.Tab.HANDS:
			_fill_hands()
		EndShopVM.Tab.SERVICES:
			_fill_services()
	var held: Array[String] = []
	for i: int in _vm.held_labels().size():
		held.append("%s %s" % [_vm.held_labels()[i], _vm.held_values()[i]])
	_slots.refresh(_vm.shop().slots(), _vm.shop().slots_text(), " · ".join(held))
	_shop.visible = not _vm.service_open()
	_bench.visible = _vm.service_open()
	_bench.refresh()


func _fill_items() -> void:
	var shelf: HBoxContainer = HBoxContainer.new()
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.add_theme_constant_override("separation", 8)
	_body.add_child(shelf)
	for row: ShopItemRow in _vm.shop().items():
		shelf.add_child(ShopCards.item(row, Callable(), _on_buy_item, false))
	if _vm.shop().items().is_empty():
		shelf.add_child(UiKit.label("Nothing left on the shelf.", Fonts.Face.BODY, 12, Palette.MUTED))
	_note("Items you don't own · one of each · buying needs a free slot")


func _fill_consumables() -> void:
	for row: ConsumableRow in _vm.shop().consumables():
		var card: PanelContainer = ShopCards.consumable(row, _on_buy_consumable)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_body.add_child(card)
	_note("Single use, spent on a manipulation made that hand · held without limit")


func _fill_hands() -> void:
	var hands: ShopHands = _vm.shop().hands()
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", ShopCards.inset())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(Icons.rect("icons/clock", 28.0, Palette.MUTED))
	var words: VBoxContainer = _stack(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(_left(UiKit.label(hands.title, Fonts.Face.BUTTON, 17, Palette.CREAM)))
	words.add_child(_left(UiKit.label(hands.text(), Fonts.Face.NUMBER, 14, Palette.GOLD)))
	var buy: Button = UiKit.button(
		"+1  %s" % hands.price_text if hands.can_buy else hands.verb, true, 15
	)
	buy.custom_minimum_size = Vector2(140.0, 44.0)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not hands.can_buy
	buy.pressed.connect(_on_buy_hand)
	row.add_child(buy)
	_note("Added to the next floor's clock")


func _fill_services() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for row: ServiceRow in _vm.services().services():
		var button: ServiceButton = ServiceButton.new(row)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_select.bind(row.service))
		grid.add_child(button)
	_note(_vm.services().deck_text() + " · every change raises the heat floor")


## A small line under a tab's goods.
func _note(text: String) -> void:
	var note: Label = _left(UiKit.label(text, Fonts.Face.BODY, 10, Palette.MUTED))
	note.clip_text = true
	_body.add_child(note)


## A dark slip of paper at a tilt, 62 tall.
func _slip(at: Vector2, width: float, tilt: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.custom_minimum_size = Vector2(width, 62.0)
	panel.rotation_degrees = tilt
	_frame.add_child(panel)
	return panel


func _stack(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	return column


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## For scripts/shot: opens the tab at this place, starts the service there.
func _shot_pick(index: int) -> void:
	_on_tab(index)


func _shot_buy(index: int) -> void:
	_on_select(_vm.services().services()[index].service)


func _on_tab(tab: int) -> void:
	_vm.pick_tab(tab as EndShopVM.Tab)
	_refresh()


func _on_buy_item(item: ItemKind.Kind) -> void:
	_vm.shop().buy_item(item)
	_refresh()


func _on_buy_consumable(kind: ConsumableRow.Kind) -> void:
	_vm.shop().buy_consumable(kind)
	_refresh()


func _on_buy_hand() -> void:
	_vm.shop().buy_hand()
	_refresh()


func _on_select(service: DeckServices.Service) -> void:
	_vm.services().select(service)
	_refresh()


func _on_elevator() -> void:
	_vm.take_elevator()
	moved.emit()
