extends GdUnitTestSuite
## The run end on screen (block U4, spec §11) for a Medium run that started
## with $50,000: quotas $140,000, $560,000, … $35,840,000; run heat marks
## 40, 70, 100; six item slots.

const PATH: String = "user://test_run_end_vm.bin"

var _f: RunFixture
var _state: RunState


func before_test() -> void:
	_f = RunFixture.new(PATH)
	_state = _f.owner.run.state


func after_test() -> void:
	_f.clear()


func _add(outcome: FloorRecord.Outcome, quota: int, bankroll: int, loan: int = 0) -> void:
	_state.records.append(
		FloorRecord.new(_state.records.size() + 1, outcome, quota, bankroll, loan)
	)


## A run ended on its last record's floor with this bankroll.
func _end(bankroll: int, won: bool = false) -> RunEndVM:
	var run: Run = _f.owner.run
	_state.bankroll = bankroll
	_state.floor_number = _state.records.size()
	_state.won = won
	_state.lost = not won
	_state.ejected = _state.records[-1].outcome == FloorRecord.Outcome.EJECTED
	run.phase = Run.Phase.WON if won else Run.Phase.LOST
	return RunEndVM.new(_f.owner)


func _won() -> RunEndVM:
	for quota: int in [140_000, 560_000, 2_240_000, 8_960_000]:
		_add(FloorRecord.Outcome.MET, quota, quota + 1_000)
	_add(FloorRecord.Outcome.MET, 35_840_000, 36_300_000)
	_state.heat_spent = 1_450.0
	return _end(36_300_000, true)


func test_the_screen_is_the_run_end() -> void:
	_won()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.RUN_END)


func test_a_won_run_shows_the_score_and_dollars_per_heat() -> void:
	var vm: RunEndVM = _won()
	var hero: RunEndHero = vm.hero()
	assert_bool(vm.won()).is_true()
	assert_str(hero.kicker).is_equal("RUN COMPLETE · FLOOR 5 CLEARED")
	assert_str(hero.title).is_equal("You beat the house.")
	assert_str(hero.sub).is_equal("Floor 5's quota reached with $460,000 to spare.")
	assert_str(hero.score_label).is_equal("FINAL SCORE")
	assert_str(hero.score_text).is_equal("$36.3M")
	assert_str(hero.per_heat_text).is_equal("$25,000 per heat")
	assert_str(hero.footnote).is_equal("Started with $50,000. Every floor met.")


func test_an_ejected_run_says_where_security_came() -> void:
	_add(FloorRecord.Outcome.MET, 140_000, 151_200)
	_add(FloorRecord.Outcome.EJECTED, 560_000, 218_400)
	var vm: RunEndVM = _end(218_400)
	var hero: RunEndHero = vm.hero()
	assert_bool(vm.won()).is_false()
	assert_str(hero.kicker).is_equal("RUN OVER · FLOOR 2")
	assert_str(hero.title).is_equal("Ejected.")
	assert_str(hero.sub).is_equal("Run heat reached 100 on floor 2. Security walked you out.")
	assert_str(hero.score_label).is_equal("BANKROLL AT THE END")
	assert_str(hero.score_text).is_equal("$218,400")
	assert_str(hero.per_heat_text).is_empty()
	assert_str(hero.footnote).is_equal("Started with $50,000. Reached floor 2 of 5.")


func test_a_short_run_says_where_the_marker_went() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 128_500, 11_500)
	_add(FloorRecord.Outcome.SHORT, 574_375, 500_000)
	var hero: RunEndHero = _end(500_000).hero()
	assert_str(hero.title).is_equal("Short on floor 2.")
	assert_str(hero.sub).is_equal("A second failure. The marker went on floor 1.")
	assert_str(hero.score_label).is_equal("BANKROLL AT THE CHECK")


func test_a_short_run_with_the_marker_unused_says_it_couldn_t_cover() -> void:
	_add(FloorRecord.Outcome.SHORT, 140_000, 20_000)
	assert_str(_end(20_000).hero().sub).is_equal("The marker couldn't cover it.")


func test_a_broke_run_says_so() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 150_000, 70_000)
	_add(FloorRecord.Outcome.BROKE, 647_500, 900)
	var hero: RunEndHero = _end(900).hero()
	assert_str(hero.title).is_equal("Broke on floor 2.")
	assert_str(hero.sub).is_equal("A second failure. The marker went on floor 1.")
	assert_str(hero.score_label).is_equal("BANKROLL AT THE END")


func test_the_heat_peak_is_named_by_the_mark_it_reached(
	peak: float, note: String, level: int,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [[12.0, "Quiet", 0], [40.0, "Pit boss", 1], [69.6, "Pit boss", 1],
		[84.0, "Sweep", 2], [100.0, "Ejected", 3]]
) -> void:
	_state.run_heat_peak = peak
	var vm: RunEndVM = _won()
	assert_str(vm.peak_text()).is_equal(str(roundi(peak)))
	assert_str(vm.peak_note()).is_equal(note)
	assert_int(vm.peak_level()).is_equal(level)
	assert_float(vm.peak_share()).is_equal_approx(peak / 100.0, 0.0001)


func test_the_heat_marks_are_labelled_from_config() -> void:
	var vm: RunEndVM = _won()
	assert_array(vm.mark_labels()).contains_exactly(["40 PIT BOSS", "70 SWEEP", "100 OUT"])
	assert_array(vm.mark_shares()).contains_exactly([0.4, 0.7, 1.0])


func test_the_items_held_at_the_end_are_listed() -> void:
	var rules: ItemRules = ItemRules.from_config(_f.config)
	_f.owner.run.kit.add_item(ItemKind.Kind.POKER_FACE, rules)
	_f.owner.run.kit.add_item(ItemKind.Kind.SLEIGHT, rules)
	var vm: RunEndVM = _won()
	assert_str(vm.item_count_text()).is_equal("2 of 6")
	assert_int(vm.slots().size()).is_equal(6)
	assert_str(vm.slots()[1].info.name).is_equal("Sleight")
	assert_bool(vm.slots()[2].filled).is_false()


func test_the_last_floor_played_is_the_one_explained_first() -> void:
	_add(FloorRecord.Outcome.MET, 140_000, 151_200)
	_add(FloorRecord.Outcome.EJECTED, 560_000, 218_400)
	var vm: RunEndVM = _end(218_400)
	assert_int(vm.floors().size()).is_equal(5)
	assert_int(vm.selected()).is_equal(1)
	assert_str(vm.detail()).is_equal("Floor 2: run heat reached 100 when a session rolled over.")
	vm.select(0)
	assert_str(vm.detail()).is_equal("Floor 1: passed $11,200 over.")
	vm.select(9)
	assert_int(vm.selected()).is_equal(0)


func test_a_new_run_starts_at_the_same_difficulty() -> void:
	_state.difficulty = 4
	_won().new_run()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_f.owner.run.state.difficulty).is_equal(4)
	assert_int(_f.owner.run.state.floor_number).is_equal(1)
	assert_object(_f.saved()).is_not_null()


func test_home_leaves_the_ended_run_behind() -> void:
	_won().home()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(_f.owner.has_save()).is_false()
