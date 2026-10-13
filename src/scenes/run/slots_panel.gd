class_name SlotsPanel
extends PanelContainer
## The kit's item slots as a small grid (spec §9), three across: each item's
## rarity and name, or EMPTY, with a line under it for what else is held.

var _count: Label
var _grid: GridContainer
var _foot: Label


func _init(p_size: Vector2) -> void:
	custom_minimum_size = p_size
	var column: VBoxContainer = UiKit.panel_column(self, 9, 4)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = UiKit.label("Your items", Fonts.Face.TITLE, 15, Palette.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = UiKit.label("", Fonts.Face.LABEL, 12, Palette.MUTED)
	head.add_child(_count)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(_grid)
	_foot = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_foot)


## foot is the line under the grid: "TAPE 1 · SEALS 0".
func refresh(slots: Array[ItemSlot], count_text: String, foot: String) -> void:
	_count.text = count_text
	_foot.text = foot
	UiKit.clear(_grid)
	for slot: ItemSlot in slots:
		_grid.add_child(_slot(slot))


func _slot(slot: ItemSlot) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET if slot.filled else Color.TRANSPARENT, 9)
	box.draw_center = slot.filled
	box.set_border_width_all(1)
	box.border_color = Color(Palette.GOLD, 0.3) if slot.filled else Palette.DIM_EDGE
	box.content_margin_left = 6
	box.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", box)
	if not slot.filled:
		panel.add_child(UiKit.label("EMPTY", Fonts.Face.LABEL, 11, Palette.OUTLINE))
		return panel
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -3)
	panel.add_child(column)
	var rarity: Label = UiKit.label(
		slot.info.rarity_text, Fonts.Face.LABEL, 9, ShopCards.RARITY_INKS[slot.info.rarity]
	)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(rarity)
	var name: Label = UiKit.label(slot.info.name, Fonts.Face.BUTTON, 12, Palette.CREAM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name)
	return panel
