class_name ServiceButton
extends Button
## A deck service as a wide button, on the deck-services screen and the end
## shop's Services tab: its name and note, and its price at the right.


func _init(row: ServiceRow) -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	disabled = not row.enabled and not row.selected
	var box: StyleBoxFlat = UiKit.filled(Palette.INSET if row.selected else Palette.BUTTON, 11)
	box.set_border_width_all(2 if row.selected else 1)
	box.border_color = Palette.GOLD if row.selected else Color(Palette.MUTED, 0.15)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, box)
	modulate.a = 0.45 if disabled else 1.0
	var line: HBoxContainer = HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 9.0
	line.offset_right = -9.0
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
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
	note.max_lines_visible = 3
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


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
