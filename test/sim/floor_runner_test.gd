extends GdUnitTestSuite
## A floor played by one bot (spec §6.1–6.3, §7.3, §12): tables until the
## bankroll reaches the quota, the clock runs out, or it can't cover a table.

const SEED: int = 31

var _config: TuneConfig = TuneConfig.load_default()


func _with(sets: Array[String]) -> TuneConfig:
	var config: SimConfig = SimConfig.from_default()
	for spec: String in sets:
		config.add_override(spec)
	return config.variants()[0].config


func _run(
	bot: String,
	bankroll: int = SimOptions.DEFAULT_BANKROLL,
	config: TuneConfig = _config,
	game: GameKind.Kind = GameKind.Kind.BLACKJACK
) -> FloorResult:
	return FloorRunner.run(config, bot, game, TableStakes.Kind.HIGH, 1, bankroll, SEED)


func _fingerprint(result: FloorResult) -> Array:
	return [result.cleared, result.hands, result.bankroll, result.run_heat, result.tables]


func test_the_same_seed_plays_the_same_floor() -> void:
	var first: FloorResult = _run("honest_adjuster")
	var second: FloorResult = _run("honest_adjuster")
	assert_array(_fingerprint(second)).is_equal(_fingerprint(first))


func test_floor_one_starts_at_the_starting_bankroll() -> void:
	assert_int(FloorRunner.starting_bankroll(_config, 1)).is_equal(
		_config.get_int("floors", "start_bankroll")
	)
	# Later floors start where the last quota left the player (§6.3).
	assert_int(FloorRunner.starting_bankroll(_config, 3)).is_equal(
		_config.get_int_list("floors", "quotas")[1]
	)


func test_a_bankroll_at_the_quota_clears_without_a_hand() -> void:
	var quota: int = _config.get_int_list("floors", "quotas")[0]
	var result: FloorResult = _run("straight_flat", quota)
	assert_bool(result.cleared).is_true()
	assert_int(result.hands).is_equal(0)


func test_the_clock_caps_the_hands_played() -> void:
	var short_clock: TuneConfig = _with(["clock.hands_per_floor=7"])
	var result: FloorResult = _run("straight_flat", SimOptions.DEFAULT_BANKROLL, short_clock)
	assert_int(result.hands).is_equal(7)
	assert_bool(result.cleared).is_false()


func test_a_back_off_moves_to_a_new_table() -> void:
	var result: FloorResult = _run("reckless_chaser")
	assert_int(result.tables).is_greater(1)
	assert_float(result.run_heat).is_greater(0.0)


func test_a_bankroll_that_cannot_cover_a_table_ends_the_floor() -> void:
	# Out of reach, so the floor can only end broke or on the clock.
	var far_quota: TuneConfig = _with(
		["floors.quotas=[1000000000, 1000000000, 1000000000, 1000000000, 1000000000]"]
	)
	var low_min: int = _config.get_int_list("floors", "low_stakes_min")[0]
	var result: FloorResult = _run("bold", low_min, far_quota)
	assert_bool(result.cleared).is_false()
	assert_int(result.bankroll).is_less(low_min)
	assert_int(result.hands).is_less(_config.get_int("clock", "hands_per_floor"))
