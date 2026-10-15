extends GdUnitTestSuite
## The run on screen (block U4): starting, saving and resuming a real Run.
## It saves after every settled hand, after every step between hands and
## when the app goes to the background; mid-hand the last save is left
## alone. Continue on the home screen resumes the saved run where it was;
## a run that ends, or is abandoned, leaves no save.

const PATH: String = "user://test_run_vm.bin"
const SEED: int = 4242

var _config: TuneConfig = TuneConfig.load_default()
var _vm: RunVM


func before_test() -> void:
	SaveStore.clear(PATH)
	_vm = _new_vm()


func after_test() -> void:
	SaveStore.clear(PATH)


func _new_vm() -> RunVM:
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = SEED
	return RunVM.new(_config, seeds, PATH)


func _saved() -> Run:
	return SaveStore.load_from(_config, PATH)


## Starts a run and sits at the first table of the first row.
func _seated() -> TableSession:
	_vm.start()
	var floor: Floor = _vm.run.floor
	floor.enter(floor.choices()[0])
	var session: TableSession = floor.sit(0)
	_vm.step_done()
	return session


func _play_hand(session: TableSession) -> void:
	session.start_hand(session.table.table_min)
	TableSessionFixture.play_out(session)
	session.finish_hand()


func test_a_launch_with_no_save_opens_home_with_nothing_to_continue() -> void:
	assert_int(_vm.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(_vm.has_save()).is_false()
	assert_str(_vm.continue_text()).is_empty()
	assert_bool(_vm.continue_run()).is_false()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.HOME)


func test_starting_a_run_opens_the_map_and_writes_a_save() -> void:
	_vm.start()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.MAP)
	assert_object(_saved()).is_not_null()
	assert_int(_vm.run.state.bankroll).is_equal(_config.get_int("floors", "start_bankroll"))


func test_the_difficulty_choices_are_the_configured_levels() -> void:
	var labels: Array[String] = []
	var chosen: Array[int] = []
	for choice: Choice in _vm.difficulty_choices():
		labels.append(choice.label)
		if choice.selected:
			chosen.append(choice.id)
	assert_array(labels).contains_exactly(["Easy", "Medium", "Hard"])
	assert_array(chosen).contains_exactly([_config.difficulty()])


func test_a_run_starts_at_the_chosen_difficulty() -> void:
	_vm.choose_difficulty(0)
	_vm.start()
	assert_int(_vm.run.state.difficulty).is_equal(0)
	_vm.choose_difficulty(99)
	assert_int(_vm.difficulty).is_equal(0)


func test_a_settled_hand_writes_a_save() -> void:
	var session: TableSession = _seated()
	_play_hand(session)
	_vm.hand_settled()
	var saved: Run = _saved()
	assert_int(saved.floor.session.bankroll).is_equal(session.bankroll)
	assert_int(saved.floor.clock.hands_left).is_equal(_vm.run.floor.clock.hands_left)
	assert_dict(saved.to_dict()).is_equal(_vm.run.to_dict())


func test_going_to_the_background_between_hands_writes_a_save() -> void:
	var session: TableSession = _seated()
	_play_hand(session)
	_vm.on_background()
	assert_dict(_saved().to_dict()).is_equal(_vm.run.to_dict())


func test_going_to_the_background_mid_hand_leaves_the_last_save_alone() -> void:
	var session: TableSession = _seated()
	var before: Dictionary = _saved().to_dict()
	session.start_hand(session.table.table_min)
	_vm.on_background()
	assert_dict(_saved().to_dict()).is_equal(before)
	assert_int(_saved().floor.session.bankroll).is_equal(_vm.run.state.bankroll)


func test_continue_resumes_with_the_same_bankroll_heat_floor_and_deck() -> void:
	var session: TableSession = _seated()
	_play_hand(session)
	_vm.hand_settled()
	_vm.run.floor.leave()
	_vm.step_done()
	var left: Dictionary = _vm.run.to_dict()
	var relaunched: RunVM = _new_vm()
	assert_bool(relaunched.has_save()).is_true()
	assert_int(relaunched.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(relaunched.continue_run()).is_true()
	assert_int(relaunched.screen()).is_equal(RunVM.Screen.MAP)
	var state: RunState = relaunched.run.state
	assert_int(state.bankroll).is_equal(_vm.run.state.bankroll)
	assert_float(state.run_heat).is_equal(_vm.run.state.run_heat)
	assert_int(state.floor_number).is_equal(_vm.run.state.floor_number)
	assert_dict(relaunched.run.game.deck.to_dict()).is_equal(_vm.run.game.deck.to_dict())
	assert_dict(relaunched.run.to_dict()).is_equal(left)


func test_the_home_screen_says_where_the_saved_run_is() -> void:
	_vm.start()
	assert_str(_new_vm().continue_text()).is_equal("Floor 1 · $50,000")


func test_an_unreadable_save_offers_only_a_new_run() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	var relaunched: RunVM = _new_vm()
	assert_bool(relaunched.has_save()).is_false()
	assert_bool(relaunched.continue_run()).is_false()
	relaunched.start()
	assert_int(relaunched.screen()).is_equal(RunVM.Screen.MAP)
	assert_object(_saved()).is_not_null()


func test_home_from_the_map_saves_and_the_run_can_be_continued() -> void:
	_vm.start()
	_vm.run.state.bankroll += 1_234
	var left: Dictionary = _vm.run.to_dict()
	_vm.go_home()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(_vm.has_save()).is_true()
	assert_bool(_vm.continue_run()).is_true()
	assert_dict(_vm.run.to_dict()).is_equal(left)


func test_abandoning_leaves_no_save() -> void:
	_vm.start()
	_vm.go_home()
	_vm.abandon()
	assert_bool(_vm.has_save()).is_false()
	assert_object(_saved()).is_null()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.HOME)


func test_a_node_of_tables_shows_its_offers_then_the_table() -> void:
	_vm.start()
	var floor: Floor = _vm.run.floor
	floor.enter(floor.choices()[0])
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.OFFERS)
	floor.sit(0)
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.TABLE)


func test_a_passed_quota_check_opens_the_end_shop_then_the_elevator() -> void:
	_vm.start()
	var floor: Floor = _vm.run.floor
	_vm.run.state.bankroll = floor.quota
	floor.cash_out()
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.END_SHOP)
	assert_dict(_saved().to_dict()).is_equal(_vm.run.to_dict())
	floor.finish()
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.ELEVATOR)
	_vm.run.ride(0)
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_saved().state.floor_number).is_equal(2)


func test_a_lost_run_shows_the_run_end_and_leaves_no_save() -> void:
	_vm.start()
	_vm.run.state.marker_used = true
	_vm.run.floor.phase = Floor.Phase.QUOTA_CHECK
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.RUN_END)
	assert_bool(_vm.run.state.lost).is_true()
	assert_object(_saved()).is_null()
	assert_bool(_vm.has_save()).is_false()


func test_a_won_run_shows_the_run_end_and_leaves_no_save() -> void:
	_vm.start()
	_vm.run.state.floor_number = TuneSchema.FLOORS
	_vm.run.state.bankroll = _vm.run.floor.quota
	_vm.run.floor.phase = Floor.Phase.QUOTA_CHECK
	_vm.step_done()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.RUN_END)
	assert_bool(_vm.run.state.won).is_true()
	assert_object(_saved()).is_null()


func test_going_to_the_background_after_the_run_ended_writes_nothing() -> void:
	_vm.start()
	_vm.run.state.marker_used = true
	_vm.run.floor.phase = Floor.Phase.QUOTA_CHECK
	_vm.step_done()
	_vm.on_background()
	assert_object(_saved()).is_null()
	_vm.go_home()
	assert_int(_vm.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(_vm.has_save()).is_false()
