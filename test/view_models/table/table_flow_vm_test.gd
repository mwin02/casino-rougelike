extends GdUnitTestSuite
## The table flow both table screens share: the hand's heat lines, the
## settled hand's summary and how the session ended, as data. An action's
## final cost shows whether or not the workings do (spec §1.4). Baccarat
## piles deal P, B, P, B; floor 1 low stakes.

## Player 9 natural against banker 5.
const PLAYER_NATURAL: Array[String] = ["9S", "2H", "KD", "3C"]

var _vm: TableFlowVM


func _sit(heat_floor: float = 0.0) -> void:
	var stacked: StackedTableDebugVM = StackedTableDebugVM.on(PLAYER_NATURAL)
	stacked.heat_floor = heat_floor
	_vm = stacked
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	_vm.sit_down()


func _finish() -> void:
	while _vm.can_proceed():
		_vm.proceed()


func test_a_settled_hand_keeps_its_summary_until_the_next_deal() -> void:
	_sit()
	assert_object(_vm.summary()).is_null()
	_vm.deal()
	_finish()
	assert_int(_vm.summary().net).is_equal(1000)
	assert_bool(_vm.summary().straight).is_true()
	_vm.deal()
	assert_object(_vm.summary()).is_null()


func test_hand_lines_show_an_action_as_it_lands_and_once_settled() -> void:
	_sit()
	_vm.deal()
	assert_array(_vm.hand_lines()).is_empty()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	_vm.picker().pick(2)
	_vm.picker().pick(PartialQuestion.Kind.HIGH)
	_vm.picker().pick(ActionPicker.ASK)
	assert_int(_vm.hand_lines().size()).is_equal(1)
	assert_int(_vm.hand_lines()[0].kind).is_equal(HeatLine.Kind.ACTION)
	_finish()
	assert_int(_vm.hand_lines()[0].kind).is_equal(HeatLine.Kind.ACTION)


func test_the_session_end_is_kept_after_leaving() -> void:
	_sit(140.0)
	assert_object(_vm.ended()).is_null()
	_vm.deal()
	_finish()
	assert_int(_vm.screen()).is_equal(TableFlowVM.Screen.SETUP)
	assert_int(_vm.ended().reason).is_equal(SessionEnd.Reason.BACKED_OFF)


func test_only_the_debug_table_shows_the_workings() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var deck: Deck = Deck.new(0)
	var flow: TableFlowVM = TableFlowVM.new(config, deck, GameRng.new(7))
	var debug: TableDebugVM = TableDebugVM.new(config, deck, GameRng.new(7))
	assert_bool(flow.reveal_workings).is_false()
	assert_bool(debug.reveal_workings).is_true()


func test_action_costs_show_before_they_are_taken() -> void:
	_sit()
	_vm.deal()
	var labels: Array[String] = StackedTableDebugVM.labels(_vm.picker().choices())
	assert_array(labels).contains(["Partial reveal " + HeatText.number(
		_vm.session().current_hand().cost_of(ActionKind.Kind.PARTIAL_REVEAL)
	)])
