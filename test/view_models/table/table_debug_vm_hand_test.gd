extends GdUnitTestSuite
## Playing hands at the debug table: heat lines as they land, the settled
## hand's summary, and sessions that end on their own (backed off,
## broke). Baccarat piles deal P, B, P, B; floor 1 low stakes, $1,000–4,000.

## Player 9 natural against banker 5.
const PLAYER_NATURAL: Array[String] = ["9S", "2H", "KD", "3C"]

var _vm: StackedTableDebugVM


func _sit(codes: Array[String] = PLAYER_NATURAL) -> void:
	_vm = StackedTableDebugVM.on(codes)
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)


func _finish() -> void:
	while _vm.can_proceed():
		_vm.proceed()


func test_a_straight_hand_settles_with_its_summary() -> void:
	_sit()
	_vm.sit_down()
	_vm.deal()
	_finish()
	assert_bool(_vm.in_hand()).is_false()
	assert_str(_vm.game().outcome_text()).is_equal("Player wins")
	assert_str(_vm.summary_text()).is_equal("+$1,000, no heat")
	assert_str(_vm.status_lines()[0]).is_equal("Bankroll $51,000")
	assert_bool(_vm.can_deal()).is_true()
	assert_str(_vm.bets.text()).is_equal("Opening bet $1,000")


func test_action_heat_shows_as_it_lands_and_in_the_summary() -> void:
	_sit()
	_vm.sit_down()
	_vm.deal()
	assert_array(_vm.heat_lines()).is_empty()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	_vm.picker().pick(2)
	_vm.picker().pick(PartialQuestion.Kind.HIGH)
	assert_int(_vm.heat_lines().size()).is_equal(1)
	assert_str(_vm.heat_lines()[0]).starts_with("Partial reveal +")
	assert_array(_vm.picker().info_lines).contains_exactly(["??: high? no"])
	_finish()
	assert_str(_vm.summary_text()).contains(" heat (")
	assert_str(_vm.heat_lines()[0]).starts_with("Partial reveal +")


func test_backed_off_ends_the_session_after_the_hand() -> void:
	_sit()
	_vm.heat_floor = 95.0
	_vm.sit_down()
	_vm.deal()
	_finish()
	assert_int(_vm.screen()).is_equal(TableDebugVM.Screen.SETUP)
	assert_str(_vm.end_text()).starts_with("You were backed off: +$1,000 over 1 hands")
	assert_str(_vm.summary_text()).is_equal("+$1,000, no heat")
	assert_array(_vm.heat_lines()).contains(["You're backed off"])


func test_going_broke_ends_the_session() -> void:
	_sit()
	_vm.bankroll = 1000
	_vm.sit_down()
	_vm.bets.choose_side(BaccaratRound.BetSide.BANKER)
	_vm.deal()
	_finish()
	assert_str(_vm.end_text()).is_equal("You went broke: -$1,000 over 1 hands, 0 run heat")
	assert_bool(_vm.can_sit_down()).is_false()
