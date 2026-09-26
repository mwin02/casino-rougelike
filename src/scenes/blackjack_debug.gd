extends Control
## Block 0 debug table. Draws BlackjackDebugVM and forwards button presses.

var _vm: BlackjackDebugVM

@onready var _dealer_cards: Label = %DealerCards
@onready var _dealer_total: Label = %DealerTotal
@onready var _player_cards: Label = %PlayerCards
@onready var _player_total: Label = %PlayerTotal
@onready var _outcome: Label = %Outcome
@onready var _net: Label = %Net
@onready var _bet: Label = %Bet
@onready var _session: Label = %Session
@onready var _deal_button: Button = %DealButton
@onready var _hit_button: Button = %HitButton
@onready var _stand_button: Button = %StandButton


func _ready() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	var run_seed: int = seed_source.randi()
	print("blackjack_debug: run seed ", run_seed)
	var rules: BlackjackRules = BlackjackRules.from_config(config)
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	var bet: int = config.get_int("debug", "debug_bet")
	_vm = BlackjackDebugVM.new(rules, bet, deck, GameRng.new(run_seed))
	_deal_button.pressed.connect(_on_deal_pressed)
	_hit_button.pressed.connect(_on_hit_pressed)
	_stand_button.pressed.connect(_on_stand_pressed)
	_refresh()


func _on_deal_pressed() -> void:
	_vm.deal()
	_refresh()


func _on_hit_pressed() -> void:
	_vm.hit()
	_refresh()


func _on_stand_pressed() -> void:
	_vm.stand()
	_refresh()


func _refresh() -> void:
	_dealer_cards.text = _vm.dealer_cards_text()
	_dealer_total.text = _vm.dealer_total_text()
	_player_cards.text = _vm.player_cards_text()
	_player_total.text = _vm.player_total_text()
	_outcome.text = _vm.outcome_text()
	_net.text = _vm.net_text()
	_bet.text = _vm.bet_text()
	_session.text = "Session " + _vm.session_net_text()
	_deal_button.disabled = not _vm.can_deal()
	_hit_button.disabled = not _vm.can_hit()
	_stand_button.disabled = not _vm.can_stand()
