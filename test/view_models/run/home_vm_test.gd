extends GdUnitTestSuite
## The home screen (block U4): Continue shows where the saved run is, a new
## run waits for the saved one to be abandoned, and abandoning takes two
## presses.

const PATH: String = "user://test_home_vm.bin"

var _config: TuneConfig = TuneConfig.load_default()
var _owner: RunVM


func before_test() -> void:
	SaveStore.clear(PATH)
	_owner = _new_owner()


func after_test() -> void:
	SaveStore.clear(PATH)


func _new_owner() -> RunVM:
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = 7
	return RunVM.new(_config, seeds, PATH)


## A home screen with a run saved on disk.
func _home_with_save() -> HomeVM:
	_owner.start()
	_owner.go_home()
	return HomeVM.new(_owner)


func test_with_no_save_only_a_new_run_is_offered() -> void:
	var home: HomeVM = HomeVM.new(_owner)
	assert_bool(home.can_continue()).is_false()
	assert_str(home.continue_label()).is_equal("Continue")
	assert_bool(home.can_abandon()).is_false()
	assert_bool(home.can_start()).is_true()
	assert_str(home.start_note()).is_empty()


func test_starting_opens_the_run_at_the_chosen_difficulty() -> void:
	var home: HomeVM = HomeVM.new(_owner)
	home.choose_difficulty(4)
	home.start()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_owner.run.state.difficulty).is_equal(4)


func test_a_saved_run_is_continued_from_where_it_was() -> void:
	var home: HomeVM = _home_with_save()
	assert_bool(home.can_continue()).is_true()
	assert_str(home.continue_label()).is_equal("Continue · Floor 1 · $50,000")
	home.continue_run()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)


func test_a_new_run_waits_for_the_saved_one_to_be_abandoned() -> void:
	var home: HomeVM = _home_with_save()
	assert_bool(home.can_start()).is_false()
	assert_str(home.start_note()).is_equal(HomeVM.START_BLOCKED)
	home.start()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.HOME)


func test_abandoning_takes_a_second_press() -> void:
	var home: HomeVM = _home_with_save()
	assert_str(home.abandon_label()).is_equal("Abandon run")
	home.press_abandon()
	assert_str(home.abandon_label()).is_equal("Tap again to abandon")
	assert_bool(_owner.has_save()).is_true()
	home.press_abandon()
	assert_bool(_owner.has_save()).is_false()
	assert_bool(home.can_continue()).is_false()
	assert_bool(home.can_start()).is_true()
	assert_str(home.abandon_label()).is_equal("Abandon run")


func test_choosing_something_else_takes_the_abandon_back() -> void:
	var home: HomeVM = _home_with_save()
	home.press_abandon()
	home.choose_difficulty(0)
	assert_str(home.abandon_label()).is_equal("Abandon run")
	home.press_abandon()
	assert_bool(_owner.has_save()).is_true()
