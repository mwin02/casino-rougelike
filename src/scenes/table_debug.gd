extends Control
## Debug table (U1). Draws TableDebugVM and forwards every press to it. Four
## columns: setup and status, the hand, the actions, and the heat. Rows of
## buttons are rebuilt from the view model's choices after every press.

const COLUMN_RATIOS: Array[float] = [1.0, 1.3, 1.3, 1.0]
const CARD_FONT_SIZE: int = 28
const TITLE_FONT_SIZE: int = 24
## Space kept clear on every side, and beyond the notch or island.
const GUTTER: int = 16

var _vm: TableDebugVM
## An empty row: a ternary with a bare [] would lose the element type.
var _no_choices: Array[Choice] = []

# Setup and status.
var _status: Label
var _setup: VBoxContainer
var _game_row: HFlowContainer
var _stakes_row: HFlowContainer
var _floor_row: HFlowContainer
var _kit_row: HFlowContainer
var _sit_down: Button
var _stand_up: Button
var _end: Label
# The hand.
var _phase: Label
var _cards: Label
var _outcome: Label
var _bet: Label
var _side_row: HFlowContainer
var _side_bet_row: HFlowContainer
var _bet_row: HFlowContainer
var _play_row: HFlowContainer
var _deal: Button
var _next: Button
var _summary: Label
# Actions.
var _prompt: Label
var _action_row: HFlowContainer
var _back: Button
var _keep_row: HFlowContainer
var _info: Label
# Heat.
var _heat: Label

@onready var _columns: HBoxContainer = %Columns
@onready var _margin: MarginContainer = $Margin


func _ready() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	var run_seed: int = seed_source.randi()
	print("table_debug: run seed ", run_seed)
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	_vm = TableDebugVM.new(config, deck, GameRng.new(run_seed))
	_fit_safe_area()
	_build()
	_refresh()


func _build() -> void:
	var left: VBoxContainer = _column(0)
	_status = _label(left)
	_setup = VBoxContainer.new()
	left.add_child(_setup)
	_game_row = _row(_setup)
	_stakes_row = _row(_setup)
	_floor_row = _row(_setup)
	_kit_row = _row(_setup)
	_sit_down = _button(_setup, "Sit down", _on_sit_down)
	_stand_up = _button(left, "Stand up", _on_stand_up)
	_end = _label(left)

	var hand: VBoxContainer = _column(1)
	_phase = _label(hand, TITLE_FONT_SIZE)
	_cards = _label(hand, CARD_FONT_SIZE)
	_outcome = _label(hand, TITLE_FONT_SIZE)
	_bet = _label(hand)
	_side_row = _row(hand)
	_side_bet_row = _row(hand)
	_bet_row = _row(hand)
	_play_row = _row(hand)
	var flow: HFlowContainer = _row(hand)
	_deal = _button(flow, "Deal", _on_deal)
	_next = _button(flow, "Next", _on_next)
	_summary = _label(hand, TITLE_FONT_SIZE)

	var actions: VBoxContainer = _column(2)
	_prompt = _label(actions, TITLE_FONT_SIZE)
	_action_row = _row(actions)
	_back = _button(actions, "Back", _on_back)
	_keep_row = _row(actions)
	_info = _label(actions)

	var heat: VBoxContainer = _column(3)
	_label(heat, TITLE_FONT_SIZE).text = "Heat"
	_heat = _label(heat)


## Keeps the columns clear of the notch or island, in canvas units.
func _fit_safe_area() -> void:
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var scale: Vector2 = get_viewport_rect().size / window if window.x > 0 else Vector2.ONE
	var insets: Dictionary[String, float] = {
		"margin_left": safe.position.x * scale.x,
		"margin_top": safe.position.y * scale.y,
		"margin_right": (window.x - safe.end.x) * scale.x,
		"margin_bottom": (window.y - safe.end.y) * scale.y,
	}
	for side: String in insets:
		_margin.add_theme_constant_override(side, maxi(int(insets[side]), 0) + GUTTER)


func _refresh() -> void:
	var at_setup: bool = _vm.screen() == TableDebugVM.Screen.SETUP
	_status.text = "\n".join(_vm.status_lines())
	_setup.visible = at_setup
	_fill(_game_row, _vm.setup.game_choices(), _vm.setup.choose_game)
	_fill(_stakes_row, _vm.setup.stakes_choices(), _vm.setup.choose_stakes)
	_fill(_floor_row, _vm.setup.floor_choices(), _vm.setup.choose_floor)
	_fill(_kit_row, _vm.setup.kit_choices(), _vm.setup.choose_kit)
	_sit_down.disabled = not _vm.can_sit_down()
	_stand_up.visible = not at_setup
	_stand_up.disabled = not _vm.can_stand_up()
	_end.text = _vm.end_text() if at_setup else ""

	var game: GameTableVM = _vm.game()
	_phase.text = game.phase_text() if game != null and _vm.in_hand() else ""
	_cards.text = "\n".join(game.card_lines()) if game != null else ""
	_outcome.text = game.outcome_text() if game != null else ""
	var seated: bool = _vm.bets != null
	_bet.text = _vm.bets.text() if seated else ""
	_fill(_side_row, _vm.bets.side_choices() if seated else _no_choices, _on_side)
	_fill(_side_bet_row, _vm.side_bets.choices() if seated else _no_choices, _on_side_bet)
	_fill(_bet_row, _vm.bets.choices() if seated else _no_choices, _vm.press_bet)
	_fill(_play_row, _vm.play_choices(), _vm.play)
	_deal.disabled = not _vm.can_deal()
	_next.disabled = not _vm.can_proceed()
	_summary.text = _vm.summary_text()

	var picker: ActionPicker = _vm.picker()
	var in_hand: bool = _vm.in_hand()
	_prompt.text = picker.prompt_text() if in_hand else "Actions"
	_fill(_action_row, picker.choices() if in_hand else _no_choices, _on_pick)
	_back.disabled = not in_hand or not picker.can_go_back()
	_fill(_keep_row, picker.keep_choices() if in_hand else _no_choices, _on_keep)
	_info.text = "\n".join(picker.info_lines) if picker != null else ""

	_heat.text = "\n".join(_vm.heat_lines())


## Replaces row's buttons with one per choice; pressing one calls
## on_press(choice.id), then redraws.
func _fill(row: HFlowContainer, choices: Array[Choice], on_press: Callable) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for choice: Choice in choices:
		var button: Button = Button.new()
		button.text = choice.label
		button.disabled = not choice.enabled
		button.toggle_mode = choice.selected
		button.button_pressed = choice.selected
		button.pressed.connect(_on_choice.bind(on_press, choice.id))
		row.add_child(button)


func _on_choice(on_press: Callable, id: int) -> void:
	on_press.call(id)
	_refresh()


func _on_pick(id: int) -> void:
	_vm.picker().pick(id)


func _on_side(id: int) -> void:
	_vm.bets.choose_side(id)


func _on_side_bet(id: int) -> void:
	_vm.side_bets.press(id)


func _on_keep(id: int) -> void:
	_vm.picker().keep(id)


func _on_sit_down() -> void:
	_vm.sit_down()
	_refresh()


func _on_stand_up() -> void:
	_vm.stand_up()
	_refresh()


func _on_deal() -> void:
	_vm.deal()
	_refresh()


func _on_next() -> void:
	_vm.proceed()
	_refresh()


func _on_back() -> void:
	_vm.picker().back()
	_refresh()


func _column(index: int) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = COLUMN_RATIOS[index]
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_columns.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	return column


func _row(parent: Container) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	return row


func _label(parent: Container, font_size: int = 0) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Container, text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button
