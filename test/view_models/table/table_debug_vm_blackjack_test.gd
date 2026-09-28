extends GdUnitTestSuite
## Blackjack through the debug table's merged steps: Next closes a window and
## its adjust, a hit's window deals the card on Next, and the final window has
## no adjust. Piles deal player, dealer up, player, hole, then hits.

var _vm: StackedTableDebugVM


func _deal(codes: Array[String]) -> void:
	_vm = StackedTableDebugVM.on(codes)
	_vm.sit_down()
	_vm.deal()


func _play(label: String) -> void:
	var choice: Choice = StackedTableDebugVM.find(_vm.play_choices(), label)
	_vm.play(choice.id)


func test_next_goes_from_the_hole_card_window_to_the_turn() -> void:
	_deal(["KS", "9H", "2D", "8C", "5H"])
	_vm.proceed()
	assert_str(_vm.game().phase_text()).is_equal("Your turn")


func test_next_on_a_hits_window_deals_the_card() -> void:
	_deal(["KS", "9H", "2D", "8C", "5H"])
	_vm.proceed()
	_play("Hit")
	assert_str(_vm.game().phase_text()).is_equal("Window: next card")
	_vm.proceed()
	assert_str(_vm.game().card_lines()[1]).is_equal("You: KS 2D 5H (17)")
	assert_str(_vm.game().phase_text()).is_equal("Your turn")


func test_the_final_window_has_no_bet_buttons() -> void:
	_deal(["KS", "9H", "7D", "8C"])
	_vm.proceed()
	_play("Stand")
	for choice: Choice in _vm.bets.choices():
		assert_bool(choice.enabled).is_false()
	_vm.proceed()
	assert_bool(_vm.in_hand()).is_false()
	assert_str(_vm.game().outcome_text()).is_equal("Push")


func test_insuring_from_the_window_leaves_the_adjust_open() -> void:
	_deal(["KS", "AH", "7D", "8C"])
	_play("Insure $500")
	assert_str(_vm.game().phase_text()).is_equal("Adjust")
	assert_str(_vm.bets.text()).is_equal("Bet $1,500 (insurance $500)")
