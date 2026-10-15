extends GdUnitTestSuite
## The elevator on screen (block U4, spec §5.3, §7.4) after floor 1 of a
## Medium run, left with $168,400: floor 2's quota is $560,000, its stakes
## $4,000–$16,000 and $20,000–$80,000. The doors open on Watchful pit and
## Short nights. A ride sheds 15 to 20 run heat; the clock is 60 hands,
## Short nights 15 fewer.

const PATH: String = "user://test_elevator_vm.bin"

var _f: RunFixture
var _vm: ElevatorVM


func after_test() -> void:
	_f.clear()


func _open(bankroll: int = 168_400, hands_bought: int = 0, run_heat: float = 46.0) -> void:
	_f = RunFixture.new(PATH, bankroll)
	_f.enter_end_shop()
	for i: int in hands_bought:
		_f.floor.shop.buy_extra_hand()
	_f.floor.finish()
	_f.owner.step_done()
	var run: Run = _f.owner.run
	# Finishing the map at the quota shed the floor's heat; this is what's left.
	run.state.run_heat = run_heat
	run.options = [
		FloorSignature.of(run.config(), FloorSignature.Kind.WATCHFUL_PIT),
		FloorSignature.of(run.config(), FloorSignature.Kind.SHORT_NIGHTS),
	]
	_vm = ElevatorVM.new(_f.owner)


func test_the_screen_is_the_elevator() -> void:
	_open()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.ELEVATOR)
	assert_str(_vm.heading()).is_equal("ELEVATOR · FLOOR 1 → FLOOR 2")
	assert_str(_vm.hint()).is_equal(
		"Two floors, two pressures. Pick the one your build can live with."
	)


func test_the_bankroll_is_set_against_the_next_quota() -> void:
	_open()
	assert_str(_vm.bankroll_text()).is_equal("$168,400")
	assert_str(_vm.quota_text()).is_equal("Floor 2 quota $560,000")
	assert_str(_vm.gap_text()).is_equal("$391,600 to go")
	assert_float(_vm.quota_share()).is_equal_approx(168_400.0 / 560_000.0, 0.0001)


func test_the_ride_shows_the_range_it_sheds_not_the_roll() -> void:
	_open()
	assert_str(_vm.heat_text()).is_equal("46")
	assert_str(_vm.heat_after_text()).is_equal("26–31")
	assert_str(_vm.shed_text()).is_equal("Ride −15 to −20")
	assert_float(_vm.heat_share()).is_equal_approx(0.46, 0.0001)
	assert_float(_vm.heat_after_share()).is_equal_approx(0.26, 0.0001)
	assert_array(_vm.hud().heat_marks()).contains_exactly([40, 70, 100])


func test_a_ride_can_t_shed_heat_that_isn_t_there() -> void:
	_open(168_400, 0, 17.0)
	assert_str(_vm.heat_after_text()).is_equal("0–2")
	_f.clear()
	_open(168_400, 0, 4.0)
	assert_str(_vm.heat_after_text()).is_equal("0")


func test_each_door_shows_its_floor() -> void:
	_open()
	var doors: Array[ElevatorOption] = _vm.options()
	assert_int(doors.size()).is_equal(2)
	assert_str(doors[0].door).is_equal("LEFT DOOR · FLOOR 2")
	assert_str(doors[0].name).is_equal("Watchful pit")
	assert_str(doors[0].plain).is_equal("The pit is on edge: every action runs hotter here.")
	assert_str(doors[0].quota_text).is_equal("$560,000")
	assert_str(doors[0].marker_text).is_empty()
	assert_str(doors[0].stakes_text).is_equal("LOW $4,000–$16,000 · HIGH $20,000–$80,000")
	assert_str(doors[0].ride_text).is_equal("Ride to Watchful pit")
	assert_str(doors[1].door).is_equal("RIGHT DOOR · FLOOR 2")
	assert_str(doors[1].name).is_equal("Short nights")


func test_the_clock_counts_the_signature_s_cut_and_extra_hands() -> void:
	_open(168_400, 3)
	var doors: Array[ElevatorOption] = _vm.options()
	assert_str(doors[0].hands_text).is_equal("63 hands")
	assert_str(doors[0].clock_note).is_equal("60 + 3 extra")
	assert_bool(doors[0].short_clock).is_false()
	assert_str(doors[1].hands_text).is_equal("48 hands")
	assert_str(doors[1].clock_note).is_equal("45 + 3 extra")
	assert_bool(doors[1].short_clock).is_true()


func test_a_clock_with_no_extra_hands_has_no_note() -> void:
	_open()
	assert_str(_vm.options()[0].hands_text).is_equal("60 hands")
	assert_str(_vm.options()[0].clock_note).is_empty()
	assert_str(_vm.options()[1].clock_note).is_equal("15 fewer")


func test_a_marker_s_debt_shows_in_the_quota() -> void:
	_open(128_500)
	assert_str(_vm.quota_text()).is_equal("Floor 2 quota $574,375")
	var door: ElevatorOption = _vm.options()[0]
	assert_str(door.quota_text).is_equal("$574,375")
	assert_str(door.marker_text).is_equal("$560,000 + $14,375 marker (loan + 25%)")


func test_the_last_floor_has_one_door() -> void:
	_open()
	var run: Run = _f.owner.run
	run.state.floor_number = TuneSchema.FLOORS
	run.options = [FloorSignature.of(run.config(), FloorSignature.Kind.BOSS)]
	_vm = ElevatorVM.new(_f.owner)
	assert_str(_vm.hint()).is_equal("One way up: the top floor.")
	assert_str(_vm.options()[0].door).is_equal("FLOOR 5")
	assert_str(_vm.options()[0].name).is_equal("Boss floor")


func test_riding_starts_the_chosen_floor_and_saves() -> void:
	_open()
	_vm.ride(1)
	var run: Run = _f.owner.run
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(run.floor.signature.kind).is_equal(FloorSignature.Kind.SHORT_NIGHTS)
	assert_int(run.floor.clock.total).is_equal(45)
	assert_float(run.state.run_heat).is_between(26.0, 31.0)
	assert_int(_f.saved().state.floor_number).is_equal(2)
