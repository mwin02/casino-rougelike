extends Control
## Debug blackjack table. Draws BlackjackDebugVM and forwards button presses.

var _vm: BlackjackDebugVM
var _buttons: Dictionary[BlackjackDebugVM.Action, Button] = {}

@onready var _phase: Label = %Phase
@onready var _dealer_cards: Label = %DealerCards
@onready var _dealer_total: Label = %DealerTotal
@onready var _player_cards: Label = %PlayerCards
@onready var _player_total: Label = %PlayerTotal
@onready var _outcome: Label = %Outcome
@onready var _net: Label = %Net
@onready var _bet: Label = %Bet
@onready var _insurance: Label = %Insurance
@onready var _session: Label = %Session


func _ready() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	var run_seed: int = seed_source.randi()
	print("blackjack_debug: run seed ", run_seed)
	var rules: BlackjackRules = BlackjackRules.from_config(config)
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	var bet: int = config.get_int("debug", "debug_bet")
	var table_min: int = config.get_int_list("floors", "low_stakes_min")[0]
	var table_max: int = config.get_int_list("floors", "low_stakes_max")[0]
	var limits: BetLimits = BetLimits.from_config(config, bet, table_min, table_max)
	_vm = BlackjackDebugVM.new(rules, limits, deck, GameRng.new(run_seed))
	_buttons = {
		BlackjackDebugVM.Action.DEAL: %DealButton,
		BlackjackDebugVM.Action.NEXT: %NextButton,
		BlackjackDebugVM.Action.HIT: %HitButton,
		BlackjackDebugVM.Action.STAND: %StandButton,
		BlackjackDebugVM.Action.DOUBLE: %DoubleButton,
		BlackjackDebugVM.Action.SPLIT: %SplitButton,
		BlackjackDebugVM.Action.INSURE: %InsureButton,
	}
	for action: BlackjackDebugVM.Action in _buttons:
		_buttons[action].pressed.connect(_on_pressed.bind(action))
	_refresh()


func _on_pressed(action: BlackjackDebugVM.Action) -> void:
	_vm.press(action)
	_refresh()


func _refresh() -> void:
	_phase.text = _vm.phase_text()
	_dealer_cards.text = _vm.dealer_cards_text()
	_dealer_total.text = _vm.dealer_total_text()
	_player_cards.text = _vm.player_cards_text()
	_player_total.text = _vm.player_total_text()
	_outcome.text = _vm.outcome_text()
	_net.text = _vm.net_text()
	_bet.text = _vm.bet_text()
	_insurance.text = _vm.insurance_text()
	_session.text = "Session " + _vm.session_net_text()
	for action: BlackjackDebugVM.Action in _buttons:
		_buttons[action].disabled = not _vm.can(action)
