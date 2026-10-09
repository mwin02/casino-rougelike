extends GdUnitTestSuite
## A whole run played by one bot (spec §5.3, §7.4, §11, §12): floor 1 to a
## win on floor 5, a loss, or an ejection, all from one seed.

const SEED: int = 5

var _config: TuneConfig = TuneConfig.load_default()


func _with(sets: Array[String]) -> TuneConfig:
	var config: SimConfig = SimConfig.from_default()
	for spec: String in sets:
		config.add_override(spec)
	assert_array(config.problems()).is_empty()
	return config.variants()[0].config


func _fingerprint(result: RunResult) -> Array:
	return [
		result.finished,
		result.won, result.ejected, result.floor_reached, result.bankroll,
		result.peak_run_heat, result.run_heat, result.hands,
	]


func test_a_full_run_completes_from_a_fixed_seed() -> void:
	var result: RunResult = RunRunner.run(_config, "honest_adjuster", SEED)
	assert_bool(result.finished).is_true()
	assert_int(result.hands).is_greater(0)
	assert_int(result.floor_reached).is_between(1, TuneSchema.FLOORS)


func test_the_same_seed_plays_the_same_run() -> void:
	var first: RunResult = RunRunner.run(_config, "manipulate_max", SEED)
	var second: RunResult = RunRunner.run(_config, "manipulate_max", SEED)
	assert_array(_fingerprint(second)).is_equal(_fingerprint(first))


## With run heat out of the way, a cheating bot can earn every floor's
## quota at its own stakes and signature. Seed 9 is one such run.
func test_a_won_run_plays_every_floor() -> void:
	var config: TuneConfig = _with(["run_heat.thresholds=[1000.0, 2000.0, 3000.0]"])
	var result: RunResult = RunRunner.run(config, "manipulate_max", 9)
	assert_bool(result.won).is_true()
	assert_int(result.floor_reached).is_equal(TuneSchema.FLOORS)
	for hands: int in result.hands_by_floor:
		assert_int(hands).is_greater(0)


func test_easy_quotas_win_the_run_on_floor_5() -> void:
	var config: TuneConfig = _with(["floors.quotas=[1000, 1000, 1000, 1000, 1000]"])
	var result: RunResult = RunRunner.run(config, "straight_flat", SEED)
	assert_bool(result.won).is_true()
	assert_int(result.floor_reached).is_equal(TuneSchema.FLOORS)


func test_a_hot_bot_is_ejected_when_the_limit_is_low() -> void:
	var config: TuneConfig = _with(["run_heat.thresholds=[1.0, 2.0, 3.0]"])
	var result: RunResult = RunRunner.run(config, "reckless_chaser", SEED)
	assert_bool(result.won).is_false()
	assert_bool(result.ejected).is_true()
	assert_float(result.peak_run_heat).is_greater_equal(3.0)


func test_a_won_run_ends_won() -> void:
	var config: TuneConfig = _with(["floors.quotas=[1000, 1000, 1000, 1000, 1000]"])
	assert_int(RunRunner.run(config, "straight_flat", SEED).end).is_equal(RunResult.End.WON)


func test_an_ejected_run_ends_ejected() -> void:
	var config: TuneConfig = _with(["run_heat.thresholds=[1.0, 2.0, 3.0]"])
	var result: RunResult = RunRunner.run(config, "reckless_chaser", SEED)
	assert_int(result.end).is_equal(RunResult.End.EJECTED)


## Out of reach, with the marker unable to cover it: lost at the check.
func test_a_run_short_at_the_check_ends_short() -> void:
	var config: TuneConfig = _with(
		["floors.quotas=[1000000000, 1000000000, 1000000000, 1000000000, 1000000000]"]
	)
	var result: RunResult = RunRunner.run(config, "straight_flat", SEED)
	assert_int(result.end).is_equal(RunResult.End.SHORT)


## A marker that fronts almost nothing: max bets go broke again. Seed 8 is
## one such run.
func test_a_run_broke_twice_ends_broke() -> void:
	var config: TuneConfig = _with(["marker.max_share_pct=1"])
	var result: RunResult = RunRunner.run(config, "bold", 8)
	assert_int(result.end).is_equal(RunResult.End.BROKE)
