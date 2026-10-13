class_name RunEndScreen
extends Control
## The run end (block U4), to the "Run end" artboard: how the run ended and
## its score on the left, the run heat peak and the items held on the
## right, the tower floor by floor across the middle, and New run at the
## foot. Draws a RunEndVM and forwards presses.

## The run has moved to another screen.
signal moved

const HERO: Rect2 = Rect2(44.0, 16.0, 396.0, 156.0)
const SIDE: Rect2 = Rect2(460.0, 16.0, 340.0, 156.0)
const FLOORS: Rect2 = Rect2(44.0, 188.0, 756.0, 124.0)
## The peak bar's fill by how many marks it reached.
const PEAK_INKS: Array[Color] = [Palette.GOLD, Palette.GOLD, Palette.RUN_HEAT, Palette.ALERT]
const TONE_INKS: Dictionary[FloorRecap.Tone, Color] = {
	FloorRecap.Tone.GOOD: Palette.WIN,
	FloorRecap.Tone.MARKER: Palette.GOLD,
	FloorRecap.Tone.BAD: Palette.ALERT,
	FloorRecap.Tone.NONE: Palette.BUTTON,
}

var _vm: RunEndVM
var _frame: DesignFrame
var _detail: Label
var _row: HBoxContainer


func _init(vm: RunEndVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new(92.0, vm.won()))
	_build_hero()
	_build_side()
	_build_floors()
	_build_foot()
	_refresh()


## How the run ended, and its score.
func _build_hero() -> void:
	var hero: RunEndHero = _vm.hero()
	var gold: bool = _vm.won()
	var panel: PanelContainer = _panel(HERO, -1.5)
	if gold:
		var box: StyleBoxFlat = panel.get_theme_stylebox("panel")
		box.border_color = Color(Palette.GOLD, 0.6)
	var tape: ColorRect = UiKit.tape(HERO.position + Vector2(26.0, -7.0), Vector2(50.0, 15.0), -6.0)
	tape.color = Color(Palette.GOLD, 0.55) if gold else Color(Palette.MUTED, 0.35)
	_frame.add_child(tape)
	var column: VBoxContainer = _stack(-2)
	panel.add_child(column)
	column.add_child(_left(UiKit.label(
		hero.kicker, Fonts.Face.LABEL, 11, Palette.GOLD if gold else Palette.MUTED
	)))
	column.add_child(_left(UiKit.label(
		hero.title, Fonts.Face.TITLE, 28, Palette.GOLD if gold else Palette.CREAM
	)))
	var sub: Label = _left(UiKit.label(hero.sub, Fonts.Face.BODY_HEAVY, 12, Palette.MUTED))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sub)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	column.add_child(foot)
	var score: VBoxContainer = _stack(-8)
	foot.add_child(score)
	score.add_child(_left(UiKit.label(hero.score_label, Fonts.Face.LABEL, 11, Palette.MUTED)))
	score.add_child(_left(UiKit.label(
		hero.score_text, Fonts.Face.NUMBER, 36, Palette.CREAM if gold else Palette.SOFT
	)))
	if hero.per_heat_text.is_empty():
		return
	var chip: PanelContainer = PanelContainer.new()
	var ground: StyleBoxFlat = UiKit.filled(Palette.GOLD, 10)
	ground.border_color = Palette.GOLD_EDGE
	ground.border_width_bottom = 3
	ground.content_margin_left = 10
	ground.content_margin_right = 10
	ground.content_margin_top = 2
	ground.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", ground)
	chip.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(chip)
	var words: VBoxContainer = _stack(-5)
	chip.add_child(words)
	words.add_child(_left(UiKit.label("WHOLE RUN", Fonts.Face.LABEL, 10, Palette.PANEL)))
	words.add_child(_left(UiKit.label(hero.per_heat_text, Fonts.Face.NUMBER, 18, Palette.PANEL)))


## The run heat peak against its marks, and the items held at the end.
func _build_side() -> void:
	var panel: PanelContainer = _panel(SIDE, 1.0)
	_frame.add_child(UiKit.tape(Vector2(700.0, 10.0), Vector2(44.0, 14.0), 5.0))
	var column: VBoxContainer = _stack(3)
	panel.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var caption: Label = _left(UiKit.label("RUN HEAT PEAK", Fonts.Face.LABEL, 11, Palette.MUTED))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	var ink: Color = PEAK_INKS[_vm.peak_level()]
	top.add_child(UiKit.label(_vm.peak_note(), Fonts.Face.LABEL, 12, Palette.MUTED))
	top.add_child(UiKit.label(_vm.peak_text(), Fonts.Face.NUMBER, 22, Palette.CREAM))
	var bar: ShareBar = ShareBar.new(Vector2(0.0, 12.0), ink)
	bar.show_share(_vm.peak_share())
	column.add_child(bar)
	var marks: Control = Control.new()
	marks.custom_minimum_size.y = 12.0
	column.add_child(marks)
	var labels: Array[String] = _vm.mark_labels()
	var shares: Array[float] = _vm.mark_shares()
	var width: float = SIDE.size.x - 28.0
	for i: int in labels.size():
		var mark: Label = UiKit.label(labels[i], Fonts.Face.LABEL, 10, Palette.MUTED)
		mark.size = Vector2(70.0, 12.0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mark.position.x = width * shares[i] - 70.0
		marks.add_child(mark)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var held: Label = _left(UiKit.label("ITEMS HELD AT THE END", Fonts.Face.LABEL, 11, Palette.MUTED))
	held.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(held)
	head.add_child(UiKit.label(_vm.item_count_text(), Fonts.Face.NUMBER, 13, Palette.CREAM))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	for slot: ItemSlot in _vm.slots():
		grid.add_child(_slot(slot))


## An item's name on a small plate, its rarity as a dot; or "Empty".
func _slot(slot: ItemSlot) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plate.custom_minimum_size.x = 10.0
	plate.clip_contents = true
	var box: StyleBoxFlat = UiKit.filled(Palette.ROW, 8)
	box.draw_center = slot.filled
	box.set_border_width_all(1)
	box.border_color = Color(Palette.GOLD, 0.25) if slot.filled else Palette.DIM_EDGE
	box.content_margin_left = 7
	box.content_margin_right = 4
	plate.add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	plate.add_child(row)
	if not slot.filled:
		row.add_child(UiKit.label("Empty", Fonts.Face.BODY_HEAVY, 11, Palette.OUTLINE))
		return plate
	var dot: ColorRect = ColorRect.new()
	dot.color = ShopCards.RARITY_INKS[slot.info.rarity]
	dot.custom_minimum_size = Vector2(6.0, 6.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var name: Label = _left(UiKit.label(slot.info.name, Fonts.Face.BODY_HEAVY, 11, Palette.CREAM))
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	return plate


func _build_floors() -> void:
	var panel: PanelContainer = _panel(FLOORS, 0.0)
	var column: VBoxContainer = _stack(6)
	panel.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	head.add_child(UiKit.label("FLOOR BY FLOOR", Fonts.Face.LABEL, 11, Palette.MUTED))
	_detail = UiKit.label("", Fonts.Face.BODY_HEAVY, 12, Palette.CREAM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.clip_text = true
	head.add_child(_detail)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_row)


func _build_foot() -> void:
	var note: Label = _left(
		UiKit.label(_vm.hero().footnote, Fonts.Face.BODY_HEAVY, 12, Palette.MUTED)
	)
	note.position = Vector2(HERO.position.x, 344.0)
	_frame.add_child(note)
	var home: Button = UiKit.button(RunEndVM.HOME, false, 16)
	home.position = Vector2(FLOORS.end.x - 320.0, 328.0)
	home.custom_minimum_size = Vector2(96.0, 48.0)
	home.pressed.connect(_on_home)
	_frame.add_child(home)
	var again: Button = UiKit.button(RunEndVM.NEW_RUN, true, 18)
	again.position = Vector2(FLOORS.end.x - 212.0, 328.0)
	again.custom_minimum_size = Vector2(212.0, 48.0)
	again.pressed.connect(_on_new_run)
	_frame.add_child(again)


func _refresh() -> void:
	_detail.text = _vm.detail()
	UiKit.clear(_row)
	var floors: Array[FloorRecap] = _vm.floors()
	for i: int in floors.size():
		_row.add_child(_floor(i, floors[i], i == _vm.selected()))


## One floor as a button: its outcome, quota and the bankroll at its check.
func _floor(index: int, recap: FloorRecap, selected: bool) -> Button:
	var reached: bool = recap.tone != FloorRecap.Tone.NONE
	var bad: bool = recap.tone == FloorRecap.Tone.BAD
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.modulate.a = 1.0 if reached else 0.6
	var box: StyleBoxFlat = UiKit.filled(Palette.ROW if reached else Palette.PANEL, 10)
	box.set_border_width_all(2 if selected else 1)
	box.border_color = Palette.DIM_EDGE
	if reached:
		box.border_color = Palette.ALERT if bad else Color(Palette.GOLD, 0.3)
	if selected:
		box.border_color = Palette.CREAM
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(_on_select.bind(index))
	var column: VBoxContainer = _stack(-3)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 9.0
	column.offset_right = -8.0
	column.offset_top = 5.0
	column.offset_bottom = -5.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var name: Label = _left(UiKit.label(recap.title, Fonts.Face.BUTTON, 15, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var chip: Label = UiKit.chip(
		recap.status, TONE_INKS[recap.tone], Palette.CHIP_INK if reached else Palette.MUTED, 10
	)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	var quota: Label = _left(UiKit.label(recap.quota_text, Fonts.Face.LABEL, 12, Palette.MUTED))
	quota.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quota.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(quota)
	column.add_child(_left(UiKit.label(recap.check_label, Fonts.Face.LABEL, 10, Palette.MUTED)))
	var ink: Color = Palette.RUN_HEAT if bad else (Palette.CREAM if reached else Palette.OUTLINE)
	column.add_child(_left(UiKit.label(recap.check_text, Fonts.Face.NUMBER, 19, ink)))
	return button


## A dark panel filling rect, at a tilt.
func _panel(rect: Rect2, tilt: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel()
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 9
	box.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", box)
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
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


## For scripts/shot: explains the floor at this place.
func _shot_pick(index: int) -> void:
	_on_select(index)


func _on_select(index: int) -> void:
	_vm.select(index)
	_refresh()


func _on_new_run() -> void:
	_vm.new_run()
	moved.emit()


func _on_home() -> void:
	_vm.home()
	moved.emit()
