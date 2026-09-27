extends GdUnitTestSuite
## A blackjack hand on the debug table (spec §3.1). Piles deal player, dealer
## up, player, hole, then hits. The hole card stays face down until the hand
## resolves.

var _fixture: ActionsFixture


func before_test() -> void:
	_fixture = ActionsFixture.new()


func _vm(codes: Array[String]) -> BlackjackTableVM:
	return GameTableVM.for_round(_fixture.blackjack(codes), _fixture.layer) as BlackjackTableVM


## Dealt, then through the hole-card window and its adjust.
func _at_turn(codes: Array[String]) -> BlackjackTableVM:
	var vm: BlackjackTableVM = _vm(codes)
	vm.proceed()
	vm.proceed()
	return vm


func _enabled(vm: BlackjackTableVM) -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in vm.play_choices():
		if choice.enabled:
			labels.append(choice.label)
	return labels


func test_the_hole_card_is_face_down_until_the_hand_resolves() -> void:
	var vm: BlackjackTableVM = _at_turn(["KS", "9H", "7D", "8C"])
	assert_array(vm.card_lines()).contains_exactly(["Dealer: 9H ??", "You: KS 7D (17)"])
	assert_str(vm.phase_text()).is_equal("Your turn")
	vm.play(BlackjackTableVM.Play.STAND)
	assert_str(vm.phase_text()).is_equal("Window: final")
	assert_str(vm.card_lines()[0]).is_equal("Dealer: 9H ??")
	vm.proceed()
	assert_array(vm.card_lines()).contains_exactly(["Dealer: 9H 8C (17)", "You: KS 7D (17)"])
	assert_str(vm.outcome_text()).is_equal("Push")


func test_soft_totals_are_labelled() -> void:
	assert_str(_vm(["AS", "9H", "6D", "5C"]).card_lines()[1]).is_equal("You: AS 6D (soft 17)")


func test_a_natural_resolves_at_once() -> void:
	var vm: BlackjackTableVM = _vm(["AS", "9H", "KD", "7C"])
	assert_str(vm.outcome_text()).is_equal("Blackjack!")
	assert_bool(vm.can_proceed()).is_false()


func test_window_phases() -> void:
	var vm: BlackjackTableVM = _vm(["KS", "9H", "2D", "8C", "5H"])
	assert_str(vm.phase_text()).is_equal("Window: hole card")
	vm.proceed()
	assert_str(vm.phase_text()).is_equal("Adjust")
	vm.proceed()
	vm.play(BlackjackTableVM.Play.HIT)
	assert_str(vm.phase_text()).is_equal("Window: next card")
	assert_str(vm.card_label(vm.game_round().window_subjects()[0])).is_equal("??")


func test_play_buttons_wait_for_the_players_turn() -> void:
	var vm: BlackjackTableVM = _vm(["KS", "9H", "7D", "8C"])
	assert_array(_enabled(vm)).is_empty()
	vm.proceed()
	vm.proceed()
	assert_array(_enabled(vm)).contains_exactly(["Hit", "Stand", "Double"])


func test_split_only_on_a_pair() -> void:
	assert_array(_enabled(_at_turn(["8S", "9H", "8D", "7C"]))).contains(["Split"])
	assert_array(_enabled(_at_turn(["KS", "9H", "QD", "7C"]))).not_contains(["Split"])


func test_split_hands_each_get_a_line_and_the_active_one_is_marked() -> void:
	var vm: BlackjackTableVM = _at_turn(["8S", "9H", "8D", "7C", "3H", "2S"])
	vm.play(BlackjackTableVM.Play.SPLIT)
	assert_array(vm.card_lines()).contains_exactly(
		["Dealer: 9H ??", "> Hand 1: 8S 3H (11)", "  Hand 2: 8D 2S (10)"]
	)
	assert_str(vm.bet_text()).is_equal("Bet $2,000")


func test_insurance_is_offered_from_the_hole_card_window() -> void:
	var vm: BlackjackTableVM = _vm(["KS", "AH", "7D", "8C"])
	assert_array(_enabled(vm)).contains_exactly(["Insure $500", "Insure $250"])
	vm.play(BlackjackTableVM.Play.INSURE_HALF)
	assert_str(vm.phase_text()).is_equal("Adjust")
	assert_str(vm.bet_text()).is_equal("Bet $1,250 (insurance $250)")
	assert_array(_enabled(vm)).is_empty()


func test_no_insurance_without_an_ace_up() -> void:
	assert_array(_enabled(_vm(["KS", "9H", "7D", "8C"]))).is_empty()


func test_every_hands_outcome_shows() -> void:
	var vm: BlackjackTableVM = _at_turn(["8S", "9H", "8D", "8C", "KH", "2S"])
	vm.play(BlackjackTableVM.Play.SPLIT)
	vm.play(BlackjackTableVM.Play.STAND)
	vm.play(BlackjackTableVM.Play.STAND)
	vm.proceed()
	assert_str(vm.outcome_text()).is_equal("You win | You lose")
	assert_str(vm.card_lines()[1]).is_equal("Hand 1: 8S KH (18)")
