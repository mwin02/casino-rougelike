class_name ServicesScreen
extends Control
## A deck-services stop (block U4), to the "Back room · deck services"
## artboard: the bankroll against the quota, the list of services at this
## floor's prices, and the bench where the picked one is worked. Draws a
## ServicesVM and forwards presses.

## The run has moved to another screen.
signal moved

const LIST: Rect2 = Rect2(44.0, 64.0, 236.0, 314.0)

var _vm: ServicesVM
var _frame: DesignFrame
var _amount: Label
var _gap: Label
var _bar: ShareBar
var _deck: Label
var _rows: VBoxContainer
var _bench: ServicesBench


func _init(vm: ServicesVM) -> void:
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
	_build_money()
	var back: Button = UiKit.button("Back to map", true, 16)
	back.icon = Icons.of("ui/icon_back")
	back.add_theme_constant_override("icon_max_width", 16)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		back.add_theme_color_override(colour, Palette.PANEL)
	back.custom_minimum_size.y = 44.0
	back.position = Vector2(646.0, 9.0)
	back.pressed.connect(_on_leave)
	_frame.add_child(back)
	_build_list()
	_bench = ServicesBench.new(vm)
	_bench.position = Vector2(292.0, LIST.position.y)
	_bench.changed.connect(_refresh)
	_frame.add_child(_bench)
	_frame.add_child(UiKit.tape(Vector2(522.0, 56.0), Vector2(48.0, 15.0), 3.0))
	_refresh()


func _build_title() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 3
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(LIST.position.x, 10.0)
	panel.custom_minimum_size = Vector2(LIST.size.x, 44.0)
	panel.rotation_degrees = -1.5
	_frame.add_child(panel)
	_frame.add_child(UiKit.tape(Vector2(130.0, 4.0), Vector2(46.0, 14.0), -4.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(Icons.rect("icons/node_deck", 22.0, Palette.GOLD))
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	row.add_child(names)
	names.add_child(_left(UiKit.label("Deck services", Fonts.Face.TITLE, 19, Palette.CREAM)))
	names.add_child(
		_left(UiKit.label("THIS STOP COSTS NO HANDS", Fonts.Face.LABEL, 10, Palette.WIN))
	)


func _build_money() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(292.0, 10.0)
	panel.custom_minimum_size = Vector2(330.0, 44.0)
	panel.rotation_degrees = 1.0
	_frame.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	top.add_child(UiKit.label("BANKROLL", Fonts.Face.LABEL, 11, Palette.MUTED))
	_amount = _left(UiKit.label("", Fonts.Face.NUMBER, 18, Palette.CREAM))
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_amount)
	_gap = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	top.add_child(_gap)
	_bar = ShareBar.new(Vector2(0.0, 8.0), Palette.GOLD)
	column.add_child(_bar)


func _build_list() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = LIST.position
	panel.custom_minimum_size = LIST.size
	panel.size = LIST.size
	_frame.add_child(panel)
	var column: VBoxContainer = UiKit.panel_column(panel, 8, 4)
	var head: HBoxContainer = ShopCards.heading(
		"SERVICES · " + _vm.hud().floor_title().get_slice(" · ", 0) + " PRICES", ""
	)
	column.add_child(head)
	_deck = head.get_child(1)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_rows)


func _refresh() -> void:
	var money: ShopMoney = _vm.money()
	_amount.text = money.bankroll_text()
	_gap.text = "%s · %s" % [money.quota_text(), money.gap_text()]
	_bar.show_share(money.shares(0).x)
	_deck.text = _vm.deck_text()
	UiKit.clear(_rows)
	for row: ServiceRow in _vm.services():
		_rows.add_child(_service_row(row))
	_bench.refresh()


## A service as a wide button: its name and note, and its price at the right.
func _service_row(row: ServiceRow) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = not row.enabled and not row.selected
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET if row.selected else Palette.BUTTON, 11)
	box.set_border_width_all(2 if row.selected else 1)
	box.border_color = Palette.GOLD if row.selected else Color(Palette.MUTED, 0.15)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.modulate.a = 0.45 if button.disabled else 1.0
	button.pressed.connect(_on_select.bind(row.service))
	var line: HBoxContainer = HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 9.0
	line.offset_right = -9.0
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	words.add_child(_left(UiKit.label(row.name, Fonts.Face.BUTTON, 14, Palette.CREAM)))
	var note: Label = _left(UiKit.label(row.note, Fonts.Face.BODY, 10, Palette.MUTED))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_constant_override("line_spacing", -3)
	note.max_lines_visible = 2
	words.add_child(note)
	var price: VBoxContainer = VBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", -3)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(price)
	var amount: Label = UiKit.label(row.price_text, Fonts.Face.NUMBER, 17, Palette.GOLD)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_child(amount)
	if not row.unit.is_empty():
		price.add_child(UiKit.label(row.unit, Fonts.Face.LABEL, 9, Palette.MUTED))
	return button


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## For scripts/shot: starts the service at this place in the list, and
## picks a card of the deck by its place.
func _shot_pick(index: int) -> void:
	_on_select(_vm.services()[index].service)


func _shot_buy(card: int) -> void:
	_vm.pick_card(_vm.cards()[card].id)
	if not _vm.rank_options().is_empty():
		_vm.choose_rank(_vm.rank_options()[-1].id)
	_refresh()


func _on_select(service: DeckServices.Service) -> void:
	_vm.select(service)
	_refresh()


func _on_leave() -> void:
	_vm.leave()
	moved.emit()
