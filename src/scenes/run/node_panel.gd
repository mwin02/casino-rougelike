class_name NodePanel
extends PanelContainer
## The map's picked node, to the design canvas: what it is, its row, its
## tables with their house rules and the pit boss's eye, a note, and the
## button that walks there. Draws a MapVM's picked node.

signal walk_pressed

const SIZE: Vector2 = Vector2(212.0, 232.0)
const GAME_ICONS: Dictionary[GameKind.Kind, String] = {
	GameKind.Kind.BLACKJACK: "icons/game_blackjack",
	GameKind.Kind.BACCARAT: "icons/game_baccarat",
	GameKind.Kind.HIGH_LOW: "icons/game_high_low",
}

var _title: Label
var _row: Label
var _sub: Label
var _tables: VBoxContainer
var _note: Label
var _walk: Button
var _cannot: Label


func _init() -> void:
	custom_minimum_size = SIZE
	var column: VBoxContainer = UiKit.panel_column(self, 12, 5)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	_title = UiKit.label("", Fonts.Face.TITLE, 17, Palette.CREAM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_row = UiKit.chip("", Palette.GOLD, Palette.PANEL, 11)
	_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_row)
	_sub = UiKit.label("", Fonts.Face.LABEL, 13, Palette.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_sub)
	_tables = VBoxContainer.new()
	_tables.add_theme_constant_override("separation", 4)
	column.add_child(_tables)
	_note = UiKit.label("", Fonts.Face.BODY, 11, Palette.SOFT)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_note.clip_text = true
	column.add_child(_note)
	_walk = UiKit.button("", true, 16)
	_walk.custom_minimum_size.y = 46.0
	_walk.icon = Icons.of("icons/arrow")
	_walk.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_walk.add_theme_constant_override("icon_max_width", 18)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		_walk.add_theme_color_override(colour, Palette.PANEL)
	for state: String in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = _walk.get_theme_stylebox(state)
		box.set_corner_radius_all(12)
	_walk.pressed.connect(walk_pressed.emit)
	column.add_child(_walk)
	_cannot = UiKit.label("", Fonts.Face.BUTTON, 14, Palette.MUTED)
	_cannot.custom_minimum_size.y = 46.0
	_cannot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var outline: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 12)
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = Palette.DIM_EDGE
	_cannot.add_theme_stylebox_override("normal", outline)
	column.add_child(_cannot)


func refresh(vm: MapVM) -> void:
	visible = vm.selected() != null
	if not visible:
		return
	_title.text = vm.selected_title()
	_row.text = vm.selected_row_text()
	_sub.text = vm.selected_sub()
	UiKit.clear(_tables)
	for offer: TableOffer in vm.selected_offers():
		_tables.add_child(_table_row(offer))
	_note.text = vm.selected_note()
	_walk.text = vm.walk_label()
	_walk.visible = vm.can_walk()
	_cannot.text = vm.walk_label()
	_cannot.visible = not vm.can_walk()


func _table_row(offer: TableOffer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.filled(Palette.ROW, 8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	if offer.watched:
		box.set_border_width_all(2)
		box.border_color = Palette.ALERT
	panel.add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	row.add_child(Icons.rect(GAME_ICONS[offer.game], 16.0, Palette.GOLD))
	var name: Label = UiKit.label(offer.name, Fonts.Face.BODY_HEAVY, 13, Palette.CREAM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if offer.rule_text != TableOffer.NO_RULE:
		row.add_child(UiKit.label(offer.rule_text, Fonts.Face.LABEL, 11, Palette.TEAL))
	if offer.watched:
		row.add_child(UiKit.chip("WATCHED", Palette.ALERT, Palette.CHIP_INK, 11))
	return panel
