class_name BetPill
extends PanelContainer
## The bet during a hand, to the design canvas: a pill with a minus, the bet
## and how it compares with the opening bet, and a plus. In a window the
## buttons set the bet the window's adjust will make.

signal changed

const HEIGHT: float = 48.0

var _vm: TableScreenVM
var _lower: Button
var _raise: Button
var _caption: Label
var _amount: Label


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel(24)
	box.set_content_margin_all(4)
	add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_lower = UiKit.round_button("−", 40.0)
	_lower.pressed.connect(_on_bet.bind(TableBetVM.Bet.DOWN))
	row.add_child(_lower)
	var words: VBoxContainer = VBoxContainer.new()
	words.custom_minimum_size.x = 84.0
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	row.add_child(words)
	_caption = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	words.add_child(_caption)
	_amount = UiKit.label("", Fonts.Face.NUMBER, 20, Palette.CREAM)
	words.add_child(_amount)
	_raise = UiKit.round_button("+", 40.0)
	_raise.pressed.connect(_on_bet.bind(TableBetVM.Bet.UP))
	row.add_child(_raise)


func refresh(vm: TableScreenVM) -> void:
	_vm = vm
	if vm.bets == null or not vm.in_hand():
		return
	var bets: TableBetVM = vm.bets
	_caption.text = "BET · " + bets.ratio_text()
	_amount.text = MoneyFormat.format(bets.shown_bet())
	var steps: Array[Choice] = bets.choices()
	_lower.disabled = not steps[TableBetVM.Bet.DOWN].enabled
	_raise.disabled = not steps[TableBetVM.Bet.UP].enabled
	reset_size()


func _on_bet(id: int) -> void:
	_vm.press_bet(id)
	changed.emit()
