extends GdUnitTestSuite
## High or Low at the debug table: a chain plays out and settles, and the bet
## locks once the chain starts (spec §3.3).

var _vm: StackedTableDebugVM


func before_test() -> void:
	_vm = StackedTableDebugVM.on(["5S", "9S", "3S", "KS", "7S"])
	_vm.setup.choose_game(GameKind.Kind.HIGH_LOW)
	_vm.sit_down()
	_vm.deal()


func test_a_banked_chain_settles_into_the_bankroll() -> void:
	_vm.play(HighLowTableVM.Play.HIGHER)
	assert_bool(_vm.in_hand()).is_true()
	_vm.play(HighLowTableVM.Play.BANK)
	assert_bool(_vm.in_hand()).is_false()
	assert_str(_vm.summary_text()).is_equal("+$240, no heat")


func test_no_bet_buttons_once_the_chain_starts() -> void:
	assert_bool(StackedTableDebugVM.find(_vm.bets.choices(), "+").enabled).is_true()
	_vm.play(HighLowTableVM.Play.HIGHER)
	_vm.play(HighLowTableVM.Play.CONTINUE)
	for choice: Choice in _vm.bets.choices():
		assert_bool(choice.enabled).is_false()


func test_a_pending_bet_is_made_when_the_call_is() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.play(HighLowTableVM.Play.HIGHER)
	assert_str(_vm.bets.text()).is_equal("Bet $2,000, chain $2,480")


func test_calls_show_only_their_odds_while_a_bet_is_pending() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.play_choices()[0].label).is_equal("Higher 3/4")
