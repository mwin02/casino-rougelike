extends GdUnitTestSuite
## Sitting down at the debug table and standing up, and what carries from
## one table to the next. Floor 1 low
## stakes is $1,000–4,000 and the bankroll starts at $50,000 (spec §6.3).

## Baccarat: player 9 natural against banker 5, so the player wins.
const PLAYER_NATURAL: Array[String] = ["9S", "2H", "KD", "3C"]

var _vm: StackedTableDebugVM


func before_test() -> void:
	_vm = StackedTableDebugVM.on(PLAYER_NATURAL)


func _sit_at_baccarat() -> void:
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	_vm.sit_down()


func _play_hand() -> void:
	_vm.deal()
	while _vm.can_proceed():
		_vm.proceed()


func test_starts_at_setup() -> void:
	assert_int(_vm.screen()).is_equal(TableDebugVM.Screen.SETUP)
	assert_array(_vm.status_lines()).contains_exactly(["Bankroll $50,000", "Run heat 0"])


func test_sitting_down_shows_the_table() -> void:
	_vm.setup.choose_stakes(TableStakes.Kind.HIGH)
	_vm.setup.choose_floor(2)
	_sit_at_baccarat()
	assert_int(_vm.screen()).is_equal(TableDebugVM.Screen.TABLE)
	assert_str(_vm.status_lines()[1]).is_equal("Baccarat, floor 2 high stakes, $25,000–$100,000")
	assert_str(_vm.status_lines()[2]).is_equal("Table heat 0 (floor 0), Clean")
	assert_str(_vm.bets.text()).is_equal("Opening bet $25,000")


## The every-action kit owns the Pit Ledger, so the table shows its rolls.
func test_the_pit_ledger_shows_in_the_status() -> void:
	_sit_at_baccarat()
	assert_str(_vm.status_lines()[3]).starts_with("Pit Ledger: ")


func test_the_starting_kit_shows_no_ledger() -> void:
	_vm.setup.choose_kit(TableSetupVM.KitChoice.STARTING)
	_sit_at_baccarat()
	for line: String in _vm.status_lines():
		assert_str(line).not_contains("Pit Ledger")


func test_cant_sit_down_below_the_table_minimum() -> void:
	_vm.bankroll = 999
	assert_bool(_vm.can_sit_down()).is_false()


func test_starting_kit_unlocks_only_the_starting_actions() -> void:
	_vm.setup.choose_kit(TableSetupVM.KitChoice.STARTING)
	_sit_at_baccarat()
	_vm.deal()
	var actions: Array[Choice] = _vm.picker().choices()
	assert_bool(actions[ActionKind.Kind.PARTIAL_REVEAL].enabled).is_true()
	assert_bool(actions[ActionKind.Kind.FULL_REVEAL].enabled).is_false()
	assert_int(_vm.setup.kit.masking_tape).is_equal(0)


func test_cant_stand_up_mid_hand() -> void:
	_sit_at_baccarat()
	_vm.deal()
	assert_bool(_vm.can_stand_up()).is_false()


func test_standing_up_returns_to_setup_with_how_it_went() -> void:
	_sit_at_baccarat()
	_play_hand()
	_vm.stand_up()
	assert_int(_vm.screen()).is_equal(TableDebugVM.Screen.SETUP)
	assert_str(_vm.end_text()).is_equal("You stood up: +$1,000 over 1 hands, 0 run heat")
	assert_array(_vm.status_lines()).contains_exactly(["Bankroll $51,000", "Run heat 0"])


func test_run_heat_and_marks_carry_to_the_next_table() -> void:
	_sit_at_baccarat()
	_vm.deal()
	_vm.picker().pick(ActionKind.Kind.MARK)
	_vm.picker().pick(0)
	_vm.picker().pick(0)
	while _vm.can_proceed():
		_vm.proceed()
	var table_heat: float = _vm.session().table_heat.heat
	_vm.stand_up()
	var share: float = TuneConfig.load_default().get_float("run_heat", "stand_up_rollover")
	assert_float(table_heat).is_greater(0.0)
	assert_float(_vm.run_heat).is_equal_approx(table_heat * share, 0.0001)
	_vm.sit_down()
	_vm.deal()
	assert_str(_vm.game().card_lines()[0]).starts_with("Player: 9S*1")


func test_swapping_the_kit_while_seated_waits_for_the_next_table() -> void:
	_sit_at_baccarat()
	_vm.setup.choose_kit(TableSetupVM.KitChoice.STARTING)
	_vm.deal()
	assert_bool(_vm.picker().choices()[ActionKind.Kind.PALM].enabled).is_true()
