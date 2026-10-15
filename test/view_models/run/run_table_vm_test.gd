extends GdUnitTestSuite
## The table of a run's floor (block U4): hands tick the floor's clock and
## save the run as they settle; leaving the table banks it with the floor
## and leaves its node, once the last hand's result has been put away.

const PATH: String = "user://test_run_table_vm.bin"
const SEED: int = 4242

var _config: TuneConfig = TuneConfig.load_default()
var _owner: RunVM
var _vm: RunTableVM


func before_test() -> void:
	SaveStore.clear(PATH)
	_owner = _new_owner()
	_owner.start()
	var floor: Floor = _owner.run.floor
	floor.enter(floor.choices()[0])
	floor.sit(0)
	_owner.step_done()
	_vm = RunTableVM.new(_owner)


func after_test() -> void:
	SaveStore.clear(PATH)


func _new_owner() -> RunVM:
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = SEED
	return RunVM.new(_config, seeds, PATH)


func _saved() -> Run:
	return SaveStore.load_from(_config, PATH)


## Deals at the opening bet and plays the hand out, with no actions.
func _play_hand() -> void:
	_vm.deal()
	for i: int in 60:
		if not _vm.in_hand():
			return
		if _vm.can_proceed():
			_vm.proceed()
			continue
		for choice: Choice in _vm.play_choices():
			if choice.enabled:
				_vm.play(choice.id)
				break
	fail("the hand never settled")


func test_the_table_is_the_one_the_floor_sat() -> void:
	var floor: Floor = _owner.run.floor
	assert_object(_vm.session()).is_same(floor.session)
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.STAKE)
	assert_str(_vm.title()).is_equal(TableSetupVM.GAME_NAMES[floor.session.table.game])
	assert_str(_vm.bankroll_text()).is_equal("$50,000")
	assert_bool(_vm.bets.fine_steps).is_true()


func test_a_hand_ticks_the_floors_clock() -> void:
	var before: int = _owner.run.floor.clock.hands_left
	assert_str(_vm.clock_text()).is_equal("%d hands left" % before)
	_play_hand()
	assert_str(_vm.clock_text()).is_equal("%d hands left" % (before - 1))


func test_the_last_hand_on_the_clock_reads_in_the_singular() -> void:
	_owner.run.floor.clock.hands_left = 1
	assert_str(_vm.clock_text()).is_equal("1 hand left")


func test_the_quota_line_shows_what_is_left_to_win() -> void:
	assert_str(_vm.quota_text()).is_equal("Quota $140,000 · $90,000 to go")
	_vm.bankroll = 140_000
	assert_str(_vm.quota_text()).is_equal("Quota $140,000 · reached")


func test_a_settled_hand_writes_a_save() -> void:
	_play_hand()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)
	var saved: Run = _saved()
	assert_int(saved.floor.session.hands_played).is_equal(1)
	assert_int(saved.floor.session.bankroll).is_equal(_vm.bankroll)
	assert_dict(saved.to_dict()).is_equal(_owner.run.to_dict())


func test_the_background_mid_hand_keeps_the_save_from_before_the_hand() -> void:
	_vm.deal()
	assert_bool(_vm.in_hand()).is_true()
	_owner.on_background()
	var saved: Run = _saved()
	assert_int(saved.floor.session.hands_played).is_equal(0)
	assert_int(saved.floor.session.bankroll).is_equal(50_000)
	assert_bool(saved.floor.session.in_hand()).is_false()


func test_leaving_the_table_banks_it_and_goes_back_to_the_map() -> void:
	_play_hand()
	_vm.continue_after_hand()
	var bankroll: int = _vm.bankroll
	_vm.stand_up()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_owner.run.state.bankroll).is_equal(bankroll)
	assert_object(_owner.run.floor.session).is_null()
	assert_object(_saved().floor.session).is_null()
	assert_int(_saved().state.bankroll).is_equal(bankroll)


func test_a_hand_that_ends_the_session_shows_its_result_before_leaving() -> void:
	_vm.session().table_heat.heat = 500.0
	_play_hand()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)
	assert_int(_vm.ended().reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	assert_int(_owner.screen()).is_equal(RunVM.Screen.TABLE)
	_vm.continue_after_hand()
	assert_int(_owner.screen()).is_not_equal(RunVM.Screen.TABLE)
	assert_object(_owner.run.floor.session).is_null()
	assert_float(_owner.run.state.run_heat).is_greater(0.0)


func test_a_run_resumed_at_an_ended_session_has_left_the_table() -> void:
	_vm.session().table_heat.heat = 500.0
	_play_hand()
	var relaunched: RunVM = _new_owner()
	assert_bool(relaunched.continue_run()).is_true()
	assert_int(relaunched.screen()).is_not_equal(RunVM.Screen.TABLE)
	assert_object(relaunched.run.floor.session).is_null()


func test_a_resumed_run_that_left_an_ended_session_is_saved_there() -> void:
	_vm.session().table_heat.heat = 500.0
	_play_hand()
	var relaunched: RunVM = _new_owner()
	relaunched.continue_run()
	assert_object(_saved().floor.session).is_null()
	assert_dict(_saved().to_dict()).is_equal(relaunched.run.to_dict())


func test_a_resume_that_ends_the_run_leaves_no_save() -> void:
	_owner.run.state.add_run_heat(99.0)
	_vm.session().table_heat.heat = 500.0
	_play_hand()
	assert_object(_saved()).is_not_null()
	var relaunched: RunVM = _new_owner()
	assert_bool(relaunched.continue_run()).is_true()
	assert_int(relaunched.screen()).is_equal(RunVM.Screen.RUN_END)
	assert_bool(relaunched.run.state.ejected).is_true()
	assert_object(_saved()).is_null()
	assert_bool(relaunched.has_save()).is_false()


func test_the_deck_screen_reads_the_runs_kit_and_deck() -> void:
	var view: DeckViewVM = _vm.deck_view()
	assert_int(view.cards().size()).is_equal(_owner.run.game.deck.cards().size())
	_vm.stand_up()
	assert_int(_vm.deck_view().cards().size()).is_equal(_owner.run.game.deck.cards().size())
