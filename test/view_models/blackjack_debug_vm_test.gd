extends GdUnitTestSuite
## What the debug table shows. Piles deal player, dealer up, player, dealer hole.

const BET: int = 1000

var _vm: BlackjackDebugVM


func before_test() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	_vm = BlackjackDebugVM.new(BlackjackRules.from_config(TuneConfig.load_default()), BET, rng)


func _deal(codes: Array[String]) -> void:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	_vm.deal_from(pile)


func test_before_first_deal_only_deal_is_enabled() -> void:
	assert_bool(_vm.can_deal()).is_true()
	assert_bool(_vm.can_hit()).is_false()
	assert_bool(_vm.can_stand()).is_false()
	assert_str(_vm.player_cards_text()).is_equal("")
	assert_str(_vm.outcome_text()).is_equal("")


func test_hole_card_hidden_during_player_turn() -> void:
	_deal(["KS", "9H", "7D", "5C"])
	assert_str(_vm.dealer_cards_text()).is_equal("9H ??")
	assert_str(_vm.dealer_total_text()).is_equal("?")
	assert_str(_vm.player_cards_text()).is_equal("KS 7D")
	assert_str(_vm.player_total_text()).is_equal("17")


func test_hole_card_revealed_after_resolution() -> void:
	_deal(["KS", "9H", "7D", "8C"])
	_vm.stand()
	assert_str(_vm.dealer_cards_text()).is_equal("9H 8C")
	assert_str(_vm.dealer_total_text()).is_equal("17")


func test_soft_total_is_labelled() -> void:
	_deal(["AS", "9H", "6D", "5C"])
	assert_str(_vm.player_total_text()).is_equal("soft 17")


func test_buttons_during_player_turn() -> void:
	_deal(["KS", "9H", "7D", "5C"])
	assert_bool(_vm.can_deal()).is_false()
	assert_bool(_vm.can_hit()).is_true()
	assert_bool(_vm.can_stand()).is_true()
	assert_str(_vm.outcome_text()).is_equal("")
	assert_str(_vm.net_text()).is_equal("")


func test_buttons_after_resolution() -> void:
	_deal(["KS", "9H", "7D", "8C"])
	_vm.stand()
	assert_bool(_vm.can_deal()).is_true()
	assert_bool(_vm.can_hit()).is_false()
	assert_bool(_vm.can_stand()).is_false()


func test_natural_shows_payout() -> void:
	_deal(["AS", "9H", "KD", "7C"])
	assert_str(_vm.outcome_text()).is_equal("Blackjack!")
	assert_str(_vm.net_text()).is_equal("+$1,500")


func test_bust_shows_loss() -> void:
	_deal(["KS", "9H", "QD", "7C", "5H"])
	_vm.hit()
	assert_str(_vm.outcome_text()).is_equal("Bust")
	assert_str(_vm.net_text()).is_equal("-$1,000")


func test_session_net_accumulates() -> void:
	_deal(["AS", "9H", "KD", "7C"])
	_deal(["KS", "9H", "QD", "7C", "5H"])
	_vm.hit()
	assert_str(_vm.session_net_text()).is_equal("+$500")


func test_deal_uses_shuffled_deck() -> void:
	_vm.deal()
	assert_str(_vm.player_cards_text()).is_not_equal("")
	assert_bool(_vm.can_deal() or _vm.can_hit()).is_true()


func test_bet_text() -> void:
	assert_str(_vm.bet_text()).is_equal("Bet $1,000")
