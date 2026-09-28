extends GdUnitTestSuite
## A baccarat hand on the debug table (spec §3.2). Piles deal P, B, P, B, then
## third cards, so the player's cards are ids 0 and 2, the banker's 1 and 3.

var _fixture: ActionsFixture


func before_test() -> void:
	_fixture = ActionsFixture.new()


func _vm(codes: Array[String]) -> BaccaratTableVM:
	return GameTableVM.for_round(_fixture.baccarat(codes), _fixture.layer) as BaccaratTableVM


func test_second_cards_are_face_down_until_they_turn_over() -> void:
	var vm: BaccaratTableVM = _vm(["9S", "2H", "KD", "3C"])
	assert_array(vm.card_lines()).contains_exactly(["Player: 9S ??", "Banker: 2H ??"])
	assert_str(vm.phase_text()).is_equal("Window: second cards")
	vm.proceed()
	assert_str(vm.phase_text()).is_equal("Adjust")
	vm.proceed()
	assert_array(vm.card_lines()).contains_exactly(["Player: 9S KD (9)", "Banker: 2H 3C (5)"])
	assert_str(vm.outcome_text()).is_equal("Player wins")
	assert_bool(vm.can_proceed()).is_false()


func test_a_third_card_has_its_own_window() -> void:
	var vm: BaccaratTableVM = _vm(["2S", "3H", "3D", "4C", "6H"])
	vm.proceed()
	vm.proceed()
	assert_str(vm.phase_text()).is_equal("Window: player's third card")
	assert_str(vm.card_label(vm.game_round().window_subjects()[0])).is_equal("??")
	vm.proceed()
	vm.proceed()
	assert_str(vm.card_lines()[0]).is_equal("Player: 2S 3D 6H (1)")


func test_outcome_is_empty_until_the_hand_settles() -> void:
	assert_str(_vm(["9S", "2H", "KD", "3C"]).outcome_text()).is_equal("")


func test_switch_side_in_an_adjust() -> void:
	var vm: BaccaratTableVM = _vm(["9S", "2H", "KD", "3C"])
	vm.proceed()
	assert_bool(vm.play_choices()[0].enabled).is_true()
	vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	assert_str(vm.bet_text()).is_equal("Bet $1,000 on Banker")


func test_switch_side_is_offered_from_the_window_before_an_adjust() -> void:
	var vm: BaccaratTableVM = _vm(["9S", "2H", "KD", "3C"])
	assert_bool(vm.play_choices()[0].enabled).is_true()
	vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	assert_str(vm.phase_text()).is_equal("Adjust")
	assert_str(vm.bet_text()).is_equal("Bet $1,000 on Banker")


func test_no_switch_once_the_hand_settles() -> void:
	var vm: BaccaratTableVM = _vm(["9S", "2H", "KD", "3C"])
	vm.proceed()
	vm.proceed()
	assert_bool(vm.play_choices()[0].enabled).is_false()


func test_a_marked_card_shows_its_symbol_face_down() -> void:
	_fixture.build_deck(["9S", "2H", "KD", "3C"])
	_fixture.deck.mark(2, 0)
	var rules: BaccaratRules = BaccaratRules.from_config(_fixture.config)
	var pile: Array[Card] = _fixture.deck.dealing_cards(_fixture.layer)
	var rnd: BaccaratRound = BaccaratRound.new(
		rules, BaccaratRound.BetSide.PLAYER, _fixture.limits(), pile
	)
	rnd.deal()
	var vm: GameTableVM = GameTableVM.for_round(rnd, _fixture.layer)
	assert_str(vm.card_lines()[0]).is_equal("Player: 9S ??*1")


func test_a_taped_card_wears_tape() -> void:
	_fixture.kit.masking_tape = 1
	var rnd: BaccaratRound = _fixture.baccarat(["9S", "2H", "KD", "3C"])
	var hand: HandActions = _fixture.actions(rnd)
	hand.nudge(0, -1)
	hand.tape(0)
	var vm: GameTableVM = GameTableVM.for_round(rnd, _fixture.layer)
	assert_str(vm.card_lines()[0]).is_equal("Player: 8S[T] ??")
