class_name StakePanel
extends PanelContainer
## The stake window's opening bet, to the design canvas: the bet between a
## minus and a plus, where it sits in the table's range, four chips to jump
## to, and where later adjusts can take it. Baccarat adds the side to bet on.

signal changed

const WIDTH: float = 280.0

var _vm: TableScreenVM
var _limits: Label
var _sides: HBoxContainer
var _lower: Button
var _raise: Button
var _amount: Label
var _range: ProgressBar
var _chips: HBoxContainer
var _note: Label


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = UiKit.panel_column(self, 12, 8)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = UiKit.label("Opening bet", Fonts.Face.TITLE, 17, Palette.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	_limits = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	head.add_child(_limits)
	_sides = _row(column)
	var stepper: HBoxContainer = HBoxContainer.new()
	column.add_child(stepper)
	_lower = UiKit.round_button("−")
	_lower.pressed.connect(_on_bet.bind(TableBetVM.Bet.DOWN))
	stepper.add_child(_lower)
	_amount = UiKit.label("", Fonts.Face.NUMBER, 34, Palette.CREAM)
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stepper.add_child(_amount)
	_raise = UiKit.round_button("+")
	_raise.pressed.connect(_on_bet.bind(TableBetVM.Bet.UP))
	stepper.add_child(_raise)
	_range = ProgressBar.new()
	_range.show_percentage = false
	_range.max_value = 1.0
	_range.custom_minimum_size.y = 8.0
	_range.add_theme_stylebox_override("background", UiKit.filled(Palette.WELL, 4))
	_range.add_theme_stylebox_override("fill", UiKit.filled(Palette.GOLD, 4))
	column.add_child(_range)
	_chips = _row(column)
	_note = UiKit.label("", Fonts.Face.BODY, 11, Palette.MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)


func refresh(vm: TableScreenVM) -> void:
	_vm = vm
	if vm.bets == null:
		return
	_limits.text = "TABLE " + vm.limits_text()
	_amount.text = MoneyFormat.format(vm.bets.opening_bet)
	var steps: Array[Choice] = vm.bets.choices()
	_lower.disabled = not steps[TableBetVM.Bet.DOWN].enabled
	_raise.disabled = not steps[TableBetVM.Bet.UP].enabled
	_range.value = vm.bets.opening_fraction()
	_fill(_sides, vm.bets.side_choices(), _on_side)
	_sides.visible = _sides.get_child_count() > 0
	# Baccarat's side row takes the room the range bar and note had.
	_range.visible = not _sides.visible
	_note.visible = not _sides.visible
	_fill(_chips, vm.bets.chips(), _on_chip)
	_note.text = "Later adjusts work from this bet: %s." % vm.stake().adjust_range_text()


func _row(column: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	return row


## One equal-width option button per choice.
func _fill(row: HBoxContainer, choices: Array[Choice], on_press: Callable) -> void:
	UiKit.clear(row)
	for choice: Choice in choices:
		var button: Button = UiKit.option(choice.label, choice.selected, 16)
		button.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
		button.custom_minimum_size.y = 40.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not choice.enabled and not choice.selected
		button.pressed.connect(on_press.bind(choice.id))
		row.add_child(button)


func _on_bet(id: int) -> void:
	_vm.press_bet(id)
	changed.emit()


func _on_chip(amount: int) -> void:
	_vm.bets.press_chip(amount)
	changed.emit()


func _on_side(id: int) -> void:
	_vm.bets.choose_side(id)
	changed.emit()
