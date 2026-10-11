extends GdUnitTestSuite
## The settle panel's result (spec §1.4): the verdict, payout rows that sum
## to the net, and the efficiency line in whole-number heat. Baccarat piles
## deal P, B, P, B; blackjack piles deal player, dealer up, player, hole.

var _vm: StackedTableScreenVM


func _sit(codes: Array[String], game: GameKind.Kind) -> void:
	_vm = StackedTableScreenVM.on(codes)
	_vm.setup.choose_game(game)
	_vm.sit_down()


func _finish() -> void:
	while _vm.can_proceed():
		_vm.proceed()


func _rows(result: HandResultVM) -> Array[String]:
	var rows: Array[String] = []
	for payout: HandResultVM.Payout in result.payouts:
		rows.append("%s %s" % [payout.label, payout.amount_text()])
	return rows


func test_there_is_no_result_until_a_hand_settles() -> void:
	_sit(["9S", "2H", "KD", "3C"], GameKind.Kind.BACCARAT)
	assert_object(_vm.result()).is_null()
	_vm.deal()
	assert_object(_vm.result()).is_null()


func test_a_straight_win_has_one_row_and_no_heat() -> void:
	_sit(["9S", "2H", "KD", "3C"], GameKind.Kind.BACCARAT)
	_vm.deal()
	_finish()
	var result: HandResultVM = _vm.result()
	assert_str(result.verdict).is_equal("Player wins")
	assert_array(_rows(result)).contains_exactly(["Main bet +$1,000"])
	assert_str(result.efficiency_text()).is_equal("+$1,000, no heat")
	assert_bool(result.is_loss()).is_false()


func test_a_loss_reads_as_a_loss() -> void:
	# Player 17 stands against a dealer 9 + 10.
	_sit(["KS", "9H", "7D", "10C", "2S"], GameKind.Kind.BLACKJACK)
	_vm.deal()
	_finish()
	_vm.play(BlackjackTableVM.Play.STAND)
	_finish()
	var result: HandResultVM = _vm.result()
	assert_str(result.verdict).is_equal("You lose")
	assert_bool(result.is_loss()).is_true()
	assert_bool(result.payouts[0].is_loss()).is_true()
	assert_str(result.efficiency_text()).is_equal("-$1,000, no heat")


func test_a_side_bet_gets_its_own_row_and_rows_sum_to_the_net() -> void:
	# Player 7H 7D: Perfect Pairs pays; 14 stands and loses to 9 + 10.
	_sit(["7H", "9S", "7D", "10C", "2S"], GameKind.Kind.BLACKJACK)
	_vm.side_bets.press(SideBetKind.Kind.PERFECT_PAIRS * SideBetsVM.Part.size())
	_vm.deal()
	_finish()
	_vm.play(BlackjackTableVM.Play.STAND)
	_finish()
	var result: HandResultVM = _vm.result()
	assert_int(result.payouts.size()).is_equal(2)
	assert_str(result.payouts[1].label).is_equal("Perfect Pairs")
	assert_bool(result.payouts[1].is_loss()).is_false()
	assert_int(result.payouts[0].dollars + result.payouts[1].dollars).is_equal(result.net)


func test_heat_shows_in_the_efficiency_line_as_the_receipt_totals_it() -> void:
	_sit(["9S", "2H", "KD", "3C"], GameKind.Kind.BACCARAT)
	_vm.deal()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	_vm.picker().pick(2)
	_vm.picker().pick(PartialQuestion.Kind.HIGH)
	_vm.picker().pick(ActionPicker.ASK)
	_finish()
	var result: HandResultVM = _vm.result()
	assert_int(result.heat).is_equal(_vm.receipt().total)
	assert_str(result.efficiency_text()).is_equal("+$1,000 for %d heat" % result.heat)
