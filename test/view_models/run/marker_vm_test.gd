extends GdUnitTestSuite
## The marker's notice (block U4, spec §11) on floor 1 of a Medium run:
## quota $140,000, low-stakes minimum $1,000. The house fronts at most half
## the quota, $70,000, at 25% interest; floor 2's quota is $560,000.

const PATH: String = "user://test_marker_vm.bin"

var _f: RunFixture


func before_test() -> void:
	_f = RunFixture.new(PATH)


func after_test() -> void:
	_f.clear()


func test_going_broke_mid_floor_shows_the_notice() -> void:
	_f.leave_table_with(600)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MARKER)
	assert_int(_f.owner.run.state.bankroll).is_equal(70_600)
	assert_int(_f.saved().state.bankroll).is_equal(70_600)


func test_leaving_a_table_with_enough_shows_no_notice() -> void:
	_f.leave_table_with(1_000)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)


func test_the_slip_says_what_was_fronted_and_why() -> void:
	_f.leave_table_with(600)
	var vm: MarkerVM = MarkerVM.new(_f.owner)
	assert_str(vm.title()).is_equal("The house fronts you $70,000.")
	assert_str(vm.reason()).is_equal(
		"You left the table with less than this floor's $1,000 low-stakes minimum."
		+ " The house keeps you playing, once."
	)
	assert_str(vm.fronted_text()).is_equal("$70,000")
	assert_str(vm.interest_label()).is_equal("Interest, 25%")
	assert_str(vm.interest_text()).is_equal("$17,500")
	assert_str(vm.owed_label()).is_equal("Added to floor 2's quota")
	assert_str(vm.owed_text()).is_equal("+$87,500")
	assert_str(vm.footer()).is_equal("BROKE MID-FLOOR · FLOOR 1")


func test_the_bankroll_and_the_next_quota_show_before_and_after() -> void:
	_f.leave_table_with(600)
	var vm: MarkerVM = MarkerVM.new(_f.owner)
	assert_str(vm.bankroll_before_text()).is_equal("$600")
	assert_str(vm.bankroll_after_text()).is_equal("$70,600")
	assert_str(vm.fronted_gain_text()).is_equal("+$70,000")
	assert_str(vm.quota_label()).is_equal("FLOOR 2 QUOTA")
	assert_str(vm.quota_before_text()).is_equal("$560,000")
	assert_str(vm.quota_after_text()).is_equal("$647,500")
	assert_str(vm.quota_note()).is_equal("The loan plus 25% interest. Shop prices don't rise.")


func test_reading_the_notice_goes_back_to_the_floor() -> void:
	_f.leave_table_with(600)
	MarkerVM.new(_f.owner).done()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	_f.owner.step_done()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)


func test_a_marker_called_at_the_quota_check_shows_in_the_end_shop_instead() -> void:
	_f.owner.run.state.bankroll = 128_500
	_f.enter_end_shop()
	assert_bool(_f.owner.run.state.marker_used).is_true()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.END_SHOP)


func test_going_broke_with_the_marker_used_ends_the_run() -> void:
	_f.owner.run.state.marker_used = true
	_f.owner.step_done()
	_f.leave_table_with(600)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.RUN_END)


func test_a_sweep_from_the_same_table_waits_behind_the_notice() -> void:
	var run: Run = _f.owner.run
	run.kit.add_item(ItemKind.Kind.WAX_PENCIL, ItemRules.from_config(_f.config))
	_f.leave_table_with(600)
	_f.floor.phase = Floor.Phase.SWEEP
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MARKER)
	MarkerVM.new(_f.owner).done()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.SWEEP)


func test_a_short_check_after_a_mid_floor_marker_ends_the_run() -> void:
	_f.leave_table_with(600)
	MarkerVM.new(_f.owner).done()
	_f.floor.phase = Floor.Phase.QUOTA_CHECK
	_f.owner.step_done()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.RUN_END)


func test_a_run_continued_from_its_save_goes_straight_on() -> void:
	_f.leave_table_with(600)
	_f.owner.go_home()
	_f.owner.continue_run()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)


func test_a_new_run_starts_with_no_notice() -> void:
	_f.leave_table_with(600)
	_f.owner.abandon()
	_f.owner.start()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
