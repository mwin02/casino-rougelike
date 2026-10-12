extends GdUnitTestSuite
## What the real table's hand controls show: the bet being moved and how it
## compares with the opening bet, which game buttons appear, and what the
## button that moves the hand on says. Blackjack piles deal player, dealer
## up, player, hole; baccarat piles deal P, B, P, B.

var _vm: StackedTableScreenVM


func _deal(codes: Array[String], game: GameKind.Kind) -> void:
	_vm = StackedTableScreenVM.on(codes)
	_vm.setup.choose_game(game)
	_vm.sit_down()
	_vm.deal()


func _shown() -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in _vm.game().shown_choices():
		labels.append(choice.label)
	return labels


func test_a_pending_bet_shows_with_its_ratio_to_the_opening_bet() -> void:
	_deal(["KS", "9H", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	assert_bool(_vm.bets.can_move()).is_true()
	assert_str(_vm.bets.ratio_text()).is_equal("OPENING")
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.shown_bet()).is_equal(2000)
	assert_str(_vm.bets.ratio_text()).is_equal("×2")
	_vm.press_bet(TableBetVM.Bet.RESET)
	assert_str(_vm.bets.ratio_text()).is_equal("OPENING")


func test_the_bet_stops_moving_once_the_adjust_is_past() -> void:
	_deal(["KS", "9H", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	_vm.proceed()
	assert_bool(_vm.bets.can_move()).is_false()
	assert_str(_vm.bets.ratio_text()).is_equal("OPENING")


func test_blackjack_shows_no_game_buttons_in_the_hole_card_window() -> void:
	_deal(["KS", "9H", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	assert_array(_shown()).is_empty()
	assert_str(_vm.game().proceed_label()).is_equal("Play hand")


func test_blackjack_offers_insurance_only_against_an_ace() -> void:
	_deal(["KS", "AH", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	assert_int(_shown().size()).is_equal(2)
	assert_str(_shown()[0]).starts_with("Insure ")


func test_blackjacks_turn_shows_all_four_plays_even_the_unusable() -> void:
	_deal(["KS", "9H", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	_vm.proceed()
	assert_array(_shown()).contains_exactly(["Hit", "Stand", "Double", "Split"])
	_vm.play(BlackjackTableVM.Play.HIT)
	assert_str(_vm.game().proceed_label()).is_equal("Deal card")
	_vm.proceed()
	_vm.play(BlackjackTableVM.Play.STAND)
	assert_str(_vm.game().proceed_label()).is_equal("Dealer plays")


func test_baccarat_turns_the_cards_and_can_switch_side_first() -> void:
	_deal(["9S", "2H", "KD", "3C"], GameKind.Kind.BACCARAT)
	assert_array(_shown()).contains_exactly(["Switch side"])
	assert_str(_vm.game().proceed_label()).is_equal("Turn cards")


func test_high_or_low_moves_on_by_its_calls_alone() -> void:
	_deal(["5S", "9S", "3S", "KS"], GameKind.Kind.HIGH_LOW)
	assert_str(_vm.game().proceed_label()).is_equal("")
	assert_int(_shown().size()).is_equal(2)
	assert_str(_shown()[0]).starts_with("Higher ")
	_vm.play(HighLowTableVM.Play.HIGHER)
	assert_array(_shown()).contains_exactly(["Bank", "Continue"])


func test_high_or_lows_felt_box_follows_the_chain() -> void:
	_deal(["5S", "9S", "3S", "KS"], GameKind.Kind.HIGH_LOW)
	var rnd: HighLowRound = _vm.game().game_round()
	assert_array(_vm.game().felt_box()).contains_exactly(
		["CHAIN · CALL 1", "$1,000", "STAKE $1,000 · %d LEFT" % rnd.remaining()]
	)
	_vm.play(HighLowTableVM.Play.HIGHER)
	_vm.play(HighLowTableVM.Play.CONTINUE)
	assert_str(_vm.game().felt_box()[0]).is_equal("CHAIN · CALL 2")
	assert_str(_vm.game().felt_box()[1]).is_equal(MoneyFormat.format(rnd.chain_value))


func test_other_games_have_no_felt_box() -> void:
	_deal(["KS", "9H", "7D", "8C", "2S"], GameKind.Kind.BLACKJACK)
	assert_array(_vm.game().felt_box()).is_empty()


func _baccarat_on(side: BaccaratRound.BetSide) -> Array[CardGroup]:
	_vm = StackedTableScreenVM.on(["9S", "2H", "KD", "3C"])
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	_vm.sit_down()
	_vm.bets.choose_side(side)
	_vm.deal()
	return _vm.game().card_groups()


func test_baccarats_chips_sit_under_the_side_bet_on() -> void:
	var groups: Array[CardGroup] = _baccarat_on(BaccaratRound.BetSide.BANKER)
	assert_int(groups.size()).is_equal(2)
	assert_int(groups[0].bet).is_equal(0)
	assert_int(groups[1].bet).is_equal(1000)


func test_switching_side_moves_the_chips() -> void:
	_baccarat_on(BaccaratRound.BetSide.PLAYER)
	assert_int(_vm.game().card_groups()[0].bet).is_greater(0)
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	var groups: Array[CardGroup] = _vm.game().card_groups()
	assert_int(groups[0].bet).is_equal(0)
	assert_int(groups[1].bet).is_greater(0)


func test_a_tie_bet_gets_a_spot_of_its_own() -> void:
	var groups: Array[CardGroup] = _baccarat_on(BaccaratRound.BetSide.TIE)
	assert_int(groups.size()).is_equal(3)
	assert_int(groups[2].role).is_equal(CardGroup.Role.TIE)
	assert_array(groups[2].cards).is_empty()
	assert_int(groups[2].bet).is_equal(1000)
	assert_int(groups[0].bet + groups[1].bet).is_equal(0)


func test_each_blackjack_hand_carries_its_stake_as_chips() -> void:
	_deal(["8S", "9H", "8D", "5C", "2S", "3H", "KD"], GameKind.Kind.BLACKJACK)
	assert_int(_vm.game().card_groups()[1].bet).is_equal(1000)
	_vm.proceed()
	_vm.play(BlackjackTableVM.Play.SPLIT)
	var groups: Array[CardGroup] = _vm.game().card_groups()
	assert_int(groups.size()).is_equal(3)
	assert_int(groups[1].bet).is_equal(1000)
	assert_int(groups[2].bet).is_equal(1000)
	assert_int(groups[0].bet).is_equal(0)


func test_high_or_lows_chips_pile_up_with_the_chain() -> void:
	_deal(["5S", "9S", "3S", "KS"], GameKind.Kind.HIGH_LOW)
	assert_int(_vm.game().felt_chips()).is_equal(1000)
	_vm.play(HighLowTableVM.Play.HIGHER)
	var rnd: HighLowRound = _vm.game().game_round()
	assert_int(_vm.game().felt_chips()).is_equal(rnd.chain_value)
	assert_int(rnd.chain_value).is_greater(1000)


func test_switching_side_three_times_costs_one_switchs_heat() -> void:
	_baccarat_on(BaccaratRound.BetSide.PLAYER)
	for i: int in 3:
		_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	while _vm.can_proceed():
		_vm.proceed()
	var switches: int = 0
	for row: HeatReceipt.Row in _vm.receipt().rows:
		if row.label == "Side switch":
			switches += 1
	assert_int(switches).is_equal(1)


func test_switching_side_and_back_is_a_straight_hand() -> void:
	_baccarat_on(BaccaratRound.BetSide.PLAYER)
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	while _vm.can_proceed():
		_vm.proceed()
	assert_bool(_vm.summary().straight).is_true()
	assert_int(_vm.receipt().total).is_equal(0)
