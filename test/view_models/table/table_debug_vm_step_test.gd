extends GdUnitTestSuite
## The merged window step: a window and the adjust after it are one step on
## screen. In the window the bet buttons set a pending bet and the actions
## stay live; the pending bet is the adjust, made as the window closes (Next,
## or a game button that closes it). The rules' order is unchanged: no action
## comes after an adjust. Baccarat piles deal P, B, P, B.

## Player 5, banker 7, so the player draws a third card (the 6H).
const PLAYER_DRAWS: Array[String] = ["2S", "3H", "3D", "4C", "6H", "9S"]

var _vm: StackedTableDebugVM


func before_test() -> void:
	_vm = StackedTableDebugVM.on(PLAYER_DRAWS)
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	_vm.sit_down()
	_vm.deal()


func _bet(label: String) -> Choice:
	return StackedTableDebugVM.find(_vm.bets.choices(), label)


func _changes() -> Array[BetChange]:
	return _vm.game().game_round().bet_changes


func test_next_closes_the_window_and_its_adjust() -> void:
	assert_str(_vm.game().phase_text()).is_equal("Window: second cards")
	_vm.proceed()
	assert_str(_vm.game().phase_text()).is_equal("Window: player's third card")


func test_a_bet_button_in_the_window_sets_a_pending_bet() -> void:
	assert_bool(_bet("+").enabled).is_true()
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.game().phase_text()).is_equal("Window: second cards")
	assert_str(_vm.bets.text()).is_equal("Bet $1,000 on Player (adjust to $2,000)")
	assert_array(_changes()).is_empty()
	assert_bool(_vm.picker().choices()[ActionKind.Kind.PARTIAL_REVEAL].enabled).is_true()


func test_next_makes_the_pending_bet() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.proceed()
	assert_str(_vm.game().phase_text()).is_equal("Window: player's third card")
	assert_str(_vm.bets.text()).is_equal("Bet $2,000 on Player")
	assert_int(_changes().size()).is_equal(1)


func test_a_pending_bet_moved_back_changes_nothing() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.press_bet(TableBetVM.Bet.DOWN)
	assert_str(_vm.bets.text()).is_equal("Bet $1,000 on Player")
	_vm.proceed()
	assert_array(_changes()).is_empty()


func test_reset_drops_the_pending_bet() -> void:
	_vm.press_bet(TableBetVM.Bet.MAX)
	assert_bool(_bet("Reset").enabled).is_true()
	_vm.press_bet(TableBetVM.Bet.RESET)
	assert_str(_vm.bets.text()).is_equal("Bet $1,000 on Player")


func test_a_manipulation_drops_the_pending_bet() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(0)
	_vm.picker().pick(ActionPicker.UP)
	for choice: Choice in _vm.bets.choices():
		assert_bool(choice.enabled).is_false()
	assert_str(_vm.bets.text()).is_equal("Bet $1,000 on Player")
	_vm.proceed()
	assert_array(_changes()).is_empty()


func test_a_side_switch_in_the_window_makes_the_pending_bet_first() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	assert_str(_vm.game().phase_text()).is_equal("Adjust")
	assert_str(_vm.bets.text()).is_equal("Bet $2,000 on Banker")


func test_bet_buttons_in_the_adjust_move_the_bet_at_once() -> void:
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.bets.text()).is_equal("Bet $2,000 on Banker")


func test_a_disabled_game_button_leaves_the_window_open() -> void:
	_vm = StackedTableDebugVM.on(PLAYER_DRAWS)
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	_vm.sit_down()
	_vm.bets.choose_side(BaccaratRound.BetSide.TIE)
	_vm.deal()
	_vm.press_bet(TableBetVM.Bet.UP)
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	assert_str(_vm.game().phase_text()).is_equal("Window: second cards")
	assert_array(_changes()).is_empty()
