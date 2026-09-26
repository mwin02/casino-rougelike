extends GdUnitTestSuite
## What the debug table shows. Piles deal player, dealer up, player, dealer hole.
## Phases, doubles, splits and insurance are in blackjack_debug_vm_phases_test.

const BET: int = 1000

var _vm: BlackjackDebugVM


func before_test() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	var rules: BlackjackRules = BlackjackRules.from_config(config)
	_vm = BlackjackDebugVM.new(rules, _limits(config), deck, GameRng.new(1))


func _deal(codes: Array[String]) -> void:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	_vm.deal_from(pile)


## Deal, then pass the hole-card window and its adjust.
func _deal_to_turn(codes: Array[String]) -> void:
	_deal(codes)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)


func test_before_first_deal_only_deal_is_enabled() -> void:
	assert_bool(_vm.can(BlackjackDebugVM.Action.DEAL)).is_true()
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.STAND)).is_false()
	assert_str(_vm.player_cards_text()).is_equal("")
	assert_str(_vm.outcome_text()).is_equal("")


func test_hole_card_hidden_during_player_turn() -> void:
	_deal_to_turn(["KS", "9H", "7D", "5C"])
	assert_str(_vm.dealer_cards_text()).is_equal("9H ??")
	assert_str(_vm.dealer_total_text()).is_equal("?")
	assert_str(_vm.player_cards_text()).is_equal("KS 7D")
	assert_str(_vm.player_total_text()).is_equal("17")


func test_hole_card_revealed_after_resolution() -> void:
	_deal_to_turn(["KS", "9H", "7D", "8C"])
	_vm.press(BlackjackDebugVM.Action.STAND)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.dealer_cards_text()).is_equal("9H 8C")
	assert_str(_vm.dealer_total_text()).is_equal("17")


func test_soft_total_is_labelled() -> void:
	_deal(["AS", "9H", "6D", "5C"])
	assert_str(_vm.player_total_text()).is_equal("soft 17")


func test_buttons_during_player_turn() -> void:
	_deal_to_turn(["KS", "9H", "7D", "5C"])
	assert_bool(_vm.can(BlackjackDebugVM.Action.DEAL)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_true()
	assert_bool(_vm.can(BlackjackDebugVM.Action.STAND)).is_true()
	assert_str(_vm.outcome_text()).is_equal("")
	assert_str(_vm.net_text()).is_equal("")


func test_buttons_after_resolution() -> void:
	_deal_to_turn(["KS", "9H", "7D", "8C"])
	_vm.press(BlackjackDebugVM.Action.STAND)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_bool(_vm.can(BlackjackDebugVM.Action.DEAL)).is_true()
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.STAND)).is_false()


func test_natural_shows_payout() -> void:
	_deal(["AS", "9H", "KD", "7C"])
	assert_str(_vm.outcome_text()).is_equal("Blackjack!")
	assert_str(_vm.net_text()).is_equal("+$1,500")


func test_bust_shows_loss() -> void:
	_deal_to_turn(["KS", "9H", "QD", "7C", "5H"])
	_vm.press(BlackjackDebugVM.Action.HIT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.outcome_text()).is_equal("Bust")
	assert_str(_vm.net_text()).is_equal("-$1,000")


func test_session_net_accumulates() -> void:
	_deal(["AS", "9H", "KD", "7C"])
	_deal_to_turn(["KS", "9H", "QD", "7C", "5H"])
	_vm.press(BlackjackDebugVM.Action.HIT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.session_net_text()).is_equal("+$500")


func _new_vm(deck: Deck, run_seed: int) -> BlackjackDebugVM:
	var rules: BlackjackRules = BlackjackRules.from_config(TuneConfig.load_default())
	return BlackjackDebugVM.new(rules, _limits(TuneConfig.load_default()), deck, GameRng.new(run_seed))


## Plays hands to resolution and returns the player's cards from each.
func _play(vm: BlackjackDebugVM, hands: int) -> Array[String]:
	var dealt: Array[String] = []
	for i: int in hands:
		vm.press(BlackjackDebugVM.Action.DEAL)
		while not vm.can(BlackjackDebugVM.Action.DEAL):
			if vm.can(BlackjackDebugVM.Action.NEXT):
				vm.press(BlackjackDebugVM.Action.NEXT)
			else:
				vm.press(BlackjackDebugVM.Action.STAND)
		dealt.append(vm.player_cards_text())
	return dealt


func test_deal_draws_from_the_owned_deck() -> void:
	var deck: Deck = Deck.new(0)
	for i: int in 10:
		deck.add_card(10, Card.Suit.HEARTS)
	var vm: BlackjackDebugVM = _new_vm(deck, 1)
	vm.press(BlackjackDebugVM.Action.DEAL)
	assert_str(vm.player_cards_text()).is_equal("10H 10H")


func test_deal_reshuffles_every_hand() -> void:
	var hands: Array[String] = _play(_new_vm(Deck.standard(20), 7), 5)
	var distinct: Dictionary[String, bool] = {}
	for hand: String in hands:
		distinct[hand] = true
	assert_int(distinct.size()).is_greater(1)
	assert_array(_play(_new_vm(Deck.standard(20), 7), 5)).is_equal(hands)


func test_bet_text() -> void:
	assert_str(_vm.bet_text()).is_equal("Bet $1,000")


## Wide table limits: the debug table's bet never moves.
func _limits(config: TuneConfig) -> BetLimits:
	return BetLimits.from_config(config, BET, 1, 100 * BET)
