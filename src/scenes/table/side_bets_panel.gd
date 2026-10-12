class_name SideBetsPanel
extends PanelContainer
## The stake window's side bets (spec §8): one row each, with its betting
## spot (chips while it's on, more as its stake grows), what wins it, a
## stake stepper, the side or rank it rides on, and its pay table. The rows
## share the panel's height, which the table sets down to the bottom row.

signal changed

const WIDTH: float = 464.0
const SPOT: Vector2 = Vector2(44.0, 46.0)
const CHIP: float = 26.0
const SIDES: Array[BaccaratRound.BetSide] = [
	BaccaratRound.BetSide.PLAYER, BaccaratRound.BetSide.BANKER,
]

var _vm: TableScreenVM
var _caption: Label
var _rows: VBoxContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = UiKit.panel_column(self, 10, 6)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = UiKit.label("Side bets", Fonts.Face.TITLE, 17, Palette.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	_caption = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	head.add_child(_caption)
	_rows = VBoxContainer.new()
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)


func refresh(vm: TableScreenVM) -> void:
	_vm = vm
	if vm.side_bets == null:
		return
	var rows: Array[SideBetRow] = vm.stake().side_rows()
	visible = not rows.is_empty()
	_caption.text = vm.side_bets.caption()
	UiKit.clear(_rows)
	for row: SideBetRow in rows:
		_rows.add_child(_build(row))


func _build(row: SideBetRow) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = UiKit.filled(Color(Palette.TEAL, 0.07 if row.on else 0.0), 10)
	box.set_border_width_all(1)
	box.border_color = Color(Palette.TEAL, 0.35) if row.on else Color(Palette.MUTED, 0.15)
	box.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	column.add_child(line)

	line.add_child(_spot(row))

	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -2)
	line.add_child(words)
	for text: Label in [
		UiKit.label(row.name, Fonts.Face.BUTTON, 15, Palette.CREAM),
		UiKit.label(row.wins, Fonts.Face.BODY, 11, Palette.MUTED),
	]:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Long text gives way to the stepper, never widens the panel.
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(text)

	if row.on:
		line.add_child(_stepper(row))
	else:
		line.add_child(UiKit.label(row.off_text, Fonts.Face.LABEL, 13, Palette.MUTED))
	if row.picks_rank:
		column.add_child(_ranks(row))
	# The side it rides on sits beside its pay table.
	var lower: HBoxContainer = HBoxContainer.new()
	lower.add_theme_constant_override("separation", 6)
	column.add_child(lower)
	if row.picks_side:
		for side: BaccaratRound.BetSide in SIDES:
			var name: String = BaccaratTableVM.SIDE_NAMES[side]
			var pick: Button = UiKit.option(name, row.side == side, 12)
			pick.disabled = not row.can_toggle
			pick.pressed.connect(_act.bind(_vm.side_bets.choose_side.bind(row.kind, side)))
			lower.add_child(pick)
	var pays: HFlowContainer = _pays(row)
	pays.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pays.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lower.add_child(pays)
	return frame


## The bet's spot: empty while it's off, a stack of chips that grows with
## its stake while it's on. Pressing it switches the bet on or off.
func _spot(row: SideBetRow) -> Button:
	var spot: Button = Button.new()
	spot.flat = true
	spot.focus_mode = Control.FOCUS_NONE
	spot.custom_minimum_size = SPOT
	spot.disabled = not row.can_toggle
	spot.modulate.a = 1.0 if row.can_toggle else 0.4
	spot.pressed.connect(_act.bind(_vm.side_bets.toggle.bind(row.kind)))
	var pile: ChipPile = ChipPile.new()
	pile.position = Vector2((SPOT.x - CHIP) / 2.0, 0.0)
	pile.size = Vector2(CHIP, SPOT.y - 2.0)
	pile.show_chips(row.chips, CHIP, SideBetsVM.FINE_STEPS, 2.0, ChipPile.SIDE)
	spot.add_child(pile)
	return spot


func _stepper(row: SideBetRow) -> HBoxContainer:
	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 4)
	var lower: Button = UiKit.round_button("−", 36.0)
	lower.disabled = not row.can_lower
	lower.pressed.connect(_act.bind(_vm.side_bets.step_stake.bind(row.kind, -1)))
	stepper.add_child(lower)
	var stake: Label = UiKit.label(row.stake_text, Fonts.Face.NUMBER, 19, Palette.TEAL)
	stake.custom_minimum_size.x = 58.0
	stepper.add_child(stake)
	var higher: Button = UiKit.round_button("+", 36.0)
	higher.disabled = not row.can_raise
	higher.pressed.connect(_act.bind(_vm.side_bets.step_stake.bind(row.kind, 1)))
	stepper.add_child(higher)
	return stepper


## Exact rank's thirteen ranks, the called one lit.
func _ranks(row: SideBetRow) -> HBoxContainer:
	var ranks: HBoxContainer = HBoxContainer.new()
	ranks.add_theme_constant_override("separation", 3)
	for rank: int in range(1, Card.RANK_CODES.size()):
		var pick: Button = UiKit.option(Card.RANK_CODES[rank], row.rank == rank, 14)
		pick.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
		pick.custom_minimum_size = Vector2(0.0, 40.0)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.disabled = not row.can_toggle
		pick.pressed.connect(_act.bind(_vm.side_bets.choose_rank.bind(rank)))
		ranks.add_child(pick)
	return ranks


## The pay table as small chips: a muted label and its odds in gold.
func _pays(row: SideBetRow) -> HFlowContainer:
	var pays: HFlowContainer = HFlowContainer.new()
	pays.add_theme_constant_override("h_separation", 4)
	pays.add_theme_constant_override("v_separation", 3)
	for pay: PackedStringArray in row.pays:
		var chip: PanelContainer = PanelContainer.new()
		var box: StyleBoxFlat = UiKit.filled(Color("232C42"), 7)
		box.content_margin_left = 7
		box.content_margin_right = 7
		chip.add_theme_stylebox_override("panel", box)
		var pair: HBoxContainer = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 4)
		chip.add_child(pair)
		pair.add_child(UiKit.label(pay[0], Fonts.Face.LABEL, 12, Palette.MUTED))
		pair.add_child(UiKit.label(pay[1], Fonts.Face.NUMBER, 12, Palette.GOLD))
		pays.add_child(chip)
	return pays


func _act(action: Callable) -> void:
	action.call()
	changed.emit()
