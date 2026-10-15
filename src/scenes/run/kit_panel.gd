class_name KitPanel
extends Control
## The kit screen (block U4), over the map, to the "Items and loadout"
## artboard: the item slots on the left, the picked item and its Discard in
## the middle, and on the right the actions with where each comes from,
## the symbols and what else is held. Draws a KitVM and forwards presses.

signal closed
## An item was discarded: the screen underneath is out of date.
signal changed

const SHADE: Color = Color(Palette.NIGHT, 0.95)
const TOP: float = 68.0
const HEIGHT: float = 308.0
const ITEMS: Rect2 = Rect2(44.0, TOP, 292.0, HEIGHT)
const DETAIL: Rect2 = Rect2(348.0, TOP, 198.0, HEIGHT)
const ACTIONS: Rect2 = Rect2(558.0, TOP, 242.0, 170.0)
const HELD: Rect2 = Rect2(558.0, 250.0, 242.0, 126.0)

var _vm: KitVM
var _count: Label
var _slots: GridContainer
var _detail: VBoxContainer
var _actions: HBoxContainer
var _symbols: VBoxContainer
var _held: VBoxContainer


func _init() -> void:
	# Taps stop here, not at the map underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var title: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 3
	box.content_margin_bottom = 5
	title.add_theme_stylebox_override("panel", box)
	title.position = Vector2(ITEMS.position.x, 12.0)
	title.custom_minimum_size = Vector2(300.0, 44.0)
	title.rotation_degrees = -1.5
	add_child(title)
	add_child(UiKit.tape(Vector2(150.0, 5.0), Vector2(46.0, 14.0), -4.0))
	var names: VBoxContainer = _stack(-4)
	title.add_child(names)
	names.add_child(_left(UiKit.label("Your kit", Fonts.Face.TITLE, 18, Palette.CREAM)))
	_count = _left(UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED))
	names.add_child(_count)
	var back: Button = UiKit.button("Back to the floor", true, 16)
	back.icon = Icons.of("ui/icon_back")
	back.add_theme_constant_override("icon_max_width", 16)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		back.add_theme_color_override(colour, Palette.PANEL)
	back.custom_minimum_size.y = 44.0
	back.position = Vector2(HELD.end.x - 190.0, 9.0)
	back.pressed.connect(_on_close)
	add_child(back)
	var items: VBoxContainer = _panel(ITEMS, "Items")
	_slots = GridContainer.new()
	_slots.columns = 2
	_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots.add_theme_constant_override("h_separation", 7)
	_slots.add_theme_constant_override("v_separation", 7)
	items.add_child(_slots)
	_detail = _panel(DETAIL, "")
	add_child(UiKit.tape(Vector2(DETAIL.position.x + 74.0, TOP - 8.0), Vector2(48.0, 15.0), 3.0))
	var actions: VBoxContainer = _panel(ACTIONS, "Actions")
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(_actions)
	var held: VBoxContainer = _panel(HELD, "")
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	held.add_child(row)
	_symbols = _stack(1)
	_symbols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_symbols)
	_held = _stack(4)
	_held.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_held)


func open(vm: KitVM) -> void:
	_vm = vm
	visible = true
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(-2000.0, -2000.0, 4000.0 + size.x, 4000.0 + size.y), SHADE)


func _refresh() -> void:
	_count.text = _vm.heading()
	UiKit.clear(_slots)
	var slots: Array[ItemSlot] = _vm.slots()
	for i: int in slots.size():
		_slots.add_child(_slot(i, slots[i], i == _vm.picked()))
	_show_detail()
	UiKit.clear(_actions)
	_actions.add_child(_family("KNOWLEDGE", Palette.TEAL, _vm.knowledge()))
	_actions.add_child(_family("MANIPULATION", Palette.RUN_HEAT, _vm.manipulation()))
	UiKit.clear(_symbols)
	_symbols.add_child(_left(UiKit.label("SYMBOLS", Fonts.Face.LABEL, 11, Palette.MUTED)))
	for symbol: LegendRow in _vm.symbols():
		_symbols.add_child(_symbol(symbol))
	UiKit.clear(_held)
	_held.add_child(_left(UiKit.label("HELD", Fonts.Face.LABEL, 11, Palette.MUTED)))
	for pair: PackedStringArray in _vm.held():
		_held.add_child(_plate(pair[0], pair[1]))


## A slot as a button: its item's rarity, name and effect, or EMPTY.
func _slot(index: int, slot: ItemSlot, picked: bool) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ground: Color = Palette.BUTTON if picked else Palette.INSET
	var box: StyleBoxFlat = UiKit.filled(ground if slot.filled else Color.TRANSPARENT, 10)
	box.draw_center = slot.filled
	box.set_border_width_all(2 if picked else 1)
	box.border_color = Palette.DIM_EDGE
	if slot.filled:
		box.border_color = Color(Palette.GOLD, 0.3)
	if picked:
		box.border_color = Palette.GOLD
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(_on_pick.bind(index))
	var column: VBoxContainer = _stack(-2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 9.0
	column.offset_right = -6.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if not slot.filled:
		column.add_child(UiKit.label("EMPTY", Fonts.Face.LABEL, 12, Palette.OUTLINE))
		column.add_child(UiKit.label("Buy items at a shop", Fonts.Face.BODY_HEAVY, 10, Palette.OUTLINE))
		return button
	column.add_child(_left(UiKit.label(
		slot.info.rarity_text, Fonts.Face.LABEL, 10, ShopCards.RARITY_INKS[slot.info.rarity]
	)))
	for text: String in [slot.info.name, slot.info.effect]:
		var first: bool = text == slot.info.name
		var line: Label = _left(UiKit.label(
			text, Fonts.Face.BUTTON if first else Fonts.Face.BODY_HEAVY, 14 if first else 10,
			Palette.CREAM if first else Palette.MUTED
		))
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(line)
	return button


## The picked item in full, with Discard; or what an empty slot is for.
func _show_detail() -> void:
	UiKit.clear(_detail)
	var info: ItemInfo = _vm.picked_item()
	if info == null:
		var none: VBoxContainer = _stack(6)
		none.alignment = BoxContainer.ALIGNMENT_CENTER
		none.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail.add_child(none)
		none.add_child(UiKit.label(KitVM.EMPTY_TITLE, Fonts.Face.BUTTON, 16, Palette.MUTED))
		none.add_child(_wrapped(KitVM.EMPTY_NOTE, 12, Palette.OUTLINE, true))
		return
	var head: HBoxContainer = HBoxContainer.new()
	_detail.add_child(head)
	var rarity: Label = UiKit.chip(
		info.rarity_text, ShopCards.RARITY_INKS[info.rarity], Palette.CHIP_INK, 11
	)
	head.add_child(rarity)
	var build: Label = UiKit.label(info.archetype, Fonts.Face.LABEL, 10, Palette.MUTED)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.clip_text = true
	head.add_child(build)
	_detail.add_child(_wrapped(info.name, 18, Palette.CREAM, false, Fonts.Face.TITLE))
	var effect: Label = _wrapped(info.effect, 12, Palette.CREAM)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(effect)
	var discard: Button = UiKit.button(_vm.discard_label(), false, 14)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		discard.add_theme_color_override(colour, Palette.LOSS)
	discard.custom_minimum_size.y = 44.0
	discard.pressed.connect(_on_discard)
	_detail.add_child(discard)
	_detail.add_child(_wrapped(_vm.discard_note(), 10, Palette.MUTED, true))


## One family of actions down a column: unlocked ones solid, locked faded.
func _family(caption: String, ink: Color, rows: Array[KitAction]) -> VBoxContainer:
	var column: VBoxContainer = _stack(3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_left(UiKit.label(caption, Fonts.Face.LABEL, 11, ink)))
	for row: KitAction in rows:
		var plate: PanelContainer = PanelContainer.new()
		plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plate.custom_minimum_size.x = 10.0
		plate.clip_contents = true
		plate.modulate.a = 0.55 if row.locked else 1.0
		var box: StyleBoxFlat = UiKit.filled(Palette.INSET, 8)
		box.draw_center = not row.locked
		box.set_border_width_all(1)
		box.border_color = Palette.DIM_EDGE if row.locked else Color(Palette.GOLD, 0.25)
		box.content_margin_left = 6
		box.content_margin_right = 4
		plate.add_theme_stylebox_override("panel", box)
		var words: VBoxContainer = _stack(-5)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		plate.add_child(words)
		var name: HBoxContainer = HBoxContainer.new()
		name.add_theme_constant_override("separation", 4)
		words.add_child(name)
		if row.locked:
			name.add_child(Icons.rect("icons/lock", 10.0, Palette.CREAM))
		name.add_child(_left(UiKit.label(row.name, Fonts.Face.BUTTON, 12, Palette.CREAM)))
		var source: Label = _left(UiKit.label(row.source, Fonts.Face.BODY_HEAVY, 9, Palette.MUTED))
		source.clip_text = true
		words.add_child(source)
		column.add_child(plate)
	return column


## "★ Star  on 4 cards".
func _symbol(symbol: LegendRow) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var icon: String = CardText.symbol_icon(symbol.symbol)
	if not icon.is_empty():
		row.add_child(Icons.rect(icon, 13.0, Palette.GOLD))
	var name: Label = _left(UiKit.label(symbol.name, Fonts.Face.BUTTON, 12, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(UiKit.label("×%d" % symbol.count, Fonts.Face.NUMBER, 13, Palette.MUTED))
	return row


## "Masking Tape ...... ×2" on a small plate.
func _plate(caption: String, amount: String) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET, 8)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	plate.add_child(row)
	var name: Label = _left(UiKit.label(caption, Fonts.Face.BUTTON, 12, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(UiKit.label(amount, Fonts.Face.NUMBER, 14, Palette.TEAL))
	return plate


## A dark panel filling rect; returns its column, under a title if given.
func _panel(rect: Rect2, title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	add_child(panel)
	var column: VBoxContainer = UiKit.panel_column(panel, 9, 3)
	if not title.is_empty():
		column.add_child(_left(UiKit.label(title, Fonts.Face.TITLE, 16, Palette.CREAM)))
	return column


func _wrapped(
	text: String, size: int, ink: Color, centred: bool = false,
	face: Fonts.Face = Fonts.Face.BODY_HEAVY
) -> Label:
	var label: Label = UiKit.label(text, face, size, ink)
	if not centred:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", -2)
	return label


func _stack(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	return column


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_pick(index: int) -> void:
	_vm.pick(index)
	_refresh()


func _on_discard() -> void:
	_vm.press_discard()
	_refresh()
	changed.emit()


func _on_close() -> void:
	visible = false
	closed.emit()
