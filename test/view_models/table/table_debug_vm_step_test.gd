extends GdUnitTestSuite
## The merged window step: a window and the adjust after it are one step on
## screen. Next closes both; the first bet button pressed in the window
## closes the window, then moves the bet. The rules' order is unchanged:
## no action comes after an adjust. Baccarat piles deal P, B, P, B.

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


func test_next_closes_the_window_and_its_adjust() -> void:
	assert_str(_vm.game().phase_text()).is_equal("Window: second cards")
	_vm.proceed()
	assert_str(_vm.game().phase_text()).is_equal("Window: player's third card")


func test_bet_buttons_are_live_in_a_window_an_adjust_follows() -> void:
	assert_bool(_bet("+").enabled).is_true()


func test_a_bet_button_in_the_window_closes_it_then_adjusts() -> void:
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.game().phase_text()).is_equal("Adjust")
	assert_str(_vm.bets.text()).is_equal("Bet $2,000 on Player")
	for choice: Choice in _vm.picker().choices():
		assert_bool(choice.enabled).is_false()
	_vm.proceed()
	assert_str(_vm.game().phase_text()).is_equal("Window: player's third card")


func test_the_picker_starts_over_when_the_window_closes() -> void:
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.picker().prompt_text()).is_equal("Choose an action")


func test_no_bet_buttons_once_the_bet_locks() -> void:
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(0)
	_vm.picker().pick(ActionPicker.UP)
	for choice: Choice in _vm.bets.choices():
		assert_bool(choice.enabled).is_false()
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_str(_vm.game().phase_text()).is_equal("Window: second cards")


func test_a_side_switch_in_the_window_closes_it_then_switches() -> void:
	assert_bool(_vm.play_choices()[0].enabled).is_true()
	_vm.play(BaccaratTableVM.Play.SWITCH_SIDE)
	assert_str(_vm.game().phase_text()).is_equal("Adjust")
	assert_str(_vm.bets.text()).is_equal("Bet $1,000 on Banker")
