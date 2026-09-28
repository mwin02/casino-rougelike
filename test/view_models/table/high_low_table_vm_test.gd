extends GdUnitTestSuite
## A High or Low chain on the debug table (spec §3.3). The deck is exactly
## the pile, dealt in order: the first card is up, the rest follow.

const PILE: Array[String] = ["5S", "9S", "3S", "KS", "7S"]

var _fixture: ActionsFixture


func before_test() -> void:
	_fixture = ActionsFixture.new()


func _vm(codes: Array[String] = PILE) -> HighLowTableVM:
	return GameTableVM.for_round(_fixture.high_low(codes), _fixture.layer) as HighLowTableVM


func _labels(vm: HighLowTableVM) -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in vm.play_choices():
		if choice.enabled:
			labels.append(choice.label)
	return labels


func test_the_card_up_and_the_next_card_face_down() -> void:
	var vm: HighLowTableVM = _vm()
	assert_array(vm.card_lines()).contains_exactly(["Up: 5S", "Next: ??"])
	assert_str(vm.phase_text()).is_equal("Window: next card")
	assert_str(vm.bet_text()).is_equal("Bet $1,000, chain $1,000")


func test_calls_show_their_odds_and_what_they_pay() -> void:
	# 3 of the 4 remaining beat the 5, 1 is under it (spec §3.3 pricing).
	assert_array(_labels(_vm())).contains_exactly(
		["Higher 3/4 pays $1,240", "Lower 1/4 pays $3,000"]
	)


func test_a_call_from_the_window_makes_the_call() -> void:
	var vm: HighLowTableVM = _vm()
	vm.play(HighLowTableVM.Play.HIGHER)
	assert_str(vm.phase_text()).is_equal("Bank or continue")
	assert_array(vm.card_lines()).contains_exactly(["Up: 9S", "Before: 5S"])
	assert_str(vm.bet_text()).is_equal("Bet $1,000, chain $1,240")
	assert_array(_labels(vm)).contains_exactly(["Bank", "Continue"])


func test_continue_opens_the_next_window_without_an_adjust() -> void:
	var vm: HighLowTableVM = _vm()
	vm.play(HighLowTableVM.Play.HIGHER)
	vm.play(HighLowTableVM.Play.CONTINUE)
	assert_str(vm.phase_text()).is_equal("Window: next card")
	vm.proceed()
	assert_str(vm.phase_text()).is_equal("Call it")


func test_banking_settles_the_chain() -> void:
	var vm: HighLowTableVM = _vm()
	vm.play(HighLowTableVM.Play.HIGHER)
	vm.play(HighLowTableVM.Play.BANK)
	assert_str(vm.outcome_text()).is_equal("Banked")
	assert_array(_labels(vm)).is_empty()
	assert_bool(vm.can_proceed()).is_false()


func test_a_wrong_call_loses() -> void:
	var vm: HighLowTableVM = _vm()
	vm.play(HighLowTableVM.Play.LOWER)
	assert_str(vm.outcome_text()).is_equal("Lost")


func test_a_tie_keeps_half() -> void:
	var vm: HighLowTableVM = _vm(["5S", "5H", "3S"])
	vm.play(HighLowTableVM.Play.HIGHER)
	assert_str(vm.outcome_text()).is_equal("Tie: half kept")


func test_a_marked_next_card_shows_its_symbol() -> void:
	_fixture.build_deck(PILE)
	_fixture.deck.mark(1, 0)
	var vm: HighLowTableVM = GameTableVM.for_round(_fixture.next_high_low(), _fixture.layer)
	assert_str(vm.card_lines()[1]).is_equal("Next: ??*1")
	vm.proceed()
	vm.proceed()
	assert_str(vm.phase_text()).is_equal("Call it")
	assert_str(vm.card_lines()[1]).is_equal("Next: ??*1")
