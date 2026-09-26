extends GdUnitTestSuite
## The debug table walks through every blackjack phase (spec §3.1) and offers
## doubles, splits and insurance. Piles deal player, dealer up, player, dealer
## hole, then player draws, then the dealer's.

const BET: int = 1000

var _vm: BlackjackDebugVM


func before_test() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	_vm = BlackjackDebugVM.new(BlackjackRules.from_config(config), BET, deck, GameRng.new(1))


func _deal(codes: Array[String]) -> void:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	_vm.deal_from(pile)


func _deal_to_turn(codes: Array[String]) -> void:
	_deal(codes)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)


func test_no_phase_before_the_first_deal() -> void:
	assert_str(_vm.phase_text()).is_equal("")
	assert_bool(_vm.can(BlackjackDebugVM.Action.NEXT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.DOUBLE)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.SPLIT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.INSURE)).is_false()


func test_deal_opens_the_hole_card_window() -> void:
	_deal(["KS", "9H", "7D", "5C"])
	assert_str(_vm.phase_text()).is_equal("Window: hole card")
	assert_bool(_vm.can(BlackjackDebugVM.Action.NEXT)).is_true()
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.STAND)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.DEAL)).is_false()


func test_next_walks_through_the_adjust_to_the_players_turn() -> void:
	_deal(["KS", "9H", "7D", "5C"])
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.phase_text()).is_equal("Adjust")
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.phase_text()).is_equal("Your turn")
	assert_bool(_vm.can(BlackjackDebugVM.Action.NEXT)).is_false()
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_true()


func test_hit_opens_a_window_on_the_next_card() -> void:
	_deal_to_turn(["2S", "9H", "3D", "5C", "4H"])
	_vm.press(BlackjackDebugVM.Action.HIT)
	assert_str(_vm.phase_text()).is_equal("Window: next card")
	assert_str(_vm.player_cards_text()).is_equal("2S 3D")
	assert_bool(_vm.can(BlackjackDebugVM.Action.HIT)).is_false()
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.player_cards_text()).is_equal("2S 3D 4H")


func test_stand_opens_the_final_window_with_the_hole_card_hidden() -> void:
	_deal_to_turn(["KS", "9H", "QD", "8C"])
	_vm.press(BlackjackDebugVM.Action.STAND)
	assert_str(_vm.phase_text()).is_equal("Window: final")
	assert_str(_vm.dealer_cards_text()).is_equal("9H ??")
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.phase_text()).is_equal("")
	assert_str(_vm.outcome_text()).is_equal("You win")


func test_insure_offered_with_an_ace_up() -> void:
	_deal(["KS", "AH", "7D", "5C"])
	assert_bool(_vm.can(BlackjackDebugVM.Action.INSURE)).is_false()
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_bool(_vm.can(BlackjackDebugVM.Action.INSURE)).is_true()
	_vm.press(BlackjackDebugVM.Action.INSURE)
	assert_bool(_vm.can(BlackjackDebugVM.Action.INSURE)).is_false()
	assert_str(_vm.insurance_text()).is_equal("Insurance $500")
	assert_str(_vm.bet_text()).is_equal("Bet $1,500")


func test_insure_not_offered_without_an_ace_up() -> void:
	_deal(["KS", "9H", "7D", "AC"])
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_bool(_vm.can(BlackjackDebugVM.Action.INSURE)).is_false()
	assert_str(_vm.insurance_text()).is_equal("")


func test_insurance_pays_on_a_dealer_natural() -> void:
	_deal(["KS", "AH", "7D", "KC"])
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.INSURE)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.STAND)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.net_text()).is_equal("$0")


func test_double_raises_the_bet_shown() -> void:
	_deal_to_turn(["5S", "10H", "6D", "7C", "9H"])
	assert_bool(_vm.can(BlackjackDebugVM.Action.DOUBLE)).is_true()
	_vm.press(BlackjackDebugVM.Action.DOUBLE)
	assert_str(_vm.bet_text()).is_equal("Bet $2,000")
	assert_str(_vm.phase_text()).is_equal("Window: next card")
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.phase_text()).is_equal("Window: final")
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.net_text()).is_equal("+$2,000")


func test_split_only_on_a_pair() -> void:
	_deal_to_turn(["KS", "9H", "QD", "5C"])
	assert_bool(_vm.can(BlackjackDebugVM.Action.SPLIT)).is_false()


func test_split_shows_every_hand_and_marks_the_active_one() -> void:
	_deal_to_turn(["8S", "10H", "8D", "7C", "3H", "2S"])
	assert_bool(_vm.can(BlackjackDebugVM.Action.SPLIT)).is_true()
	_vm.press(BlackjackDebugVM.Action.SPLIT)
	assert_str(_vm.player_cards_text()).is_equal("> 8S 3H\n  8D 2S")
	assert_str(_vm.player_total_text()).is_equal("11 | 10")
	assert_str(_vm.bet_text()).is_equal("Bet $2,000")
	assert_str(_vm.outcome_text()).is_equal("")
	_vm.press(BlackjackDebugVM.Action.STAND)
	assert_str(_vm.player_cards_text()).is_equal("  8S 3H\n> 8D 2S")


func test_split_hands_settle_separately() -> void:
	# Hand 1: 8+3 hits 9 for 20. Hand 2: 8+2 stands on 10. Dealer 17.
	_deal_to_turn(["8S", "10H", "8D", "7C", "3H", "2S", "9C"])
	_vm.press(BlackjackDebugVM.Action.SPLIT)
	_vm.press(BlackjackDebugVM.Action.HIT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	_vm.press(BlackjackDebugVM.Action.STAND)
	_vm.press(BlackjackDebugVM.Action.STAND)
	_vm.press(BlackjackDebugVM.Action.NEXT)
	assert_str(_vm.player_cards_text()).is_equal("8S 3H 9C\n8D 2S")
	assert_str(_vm.outcome_text()).is_equal("You win | You lose")
	assert_str(_vm.net_text()).is_equal("$0")
