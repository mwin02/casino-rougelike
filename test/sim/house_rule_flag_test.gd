extends GdUnitTestSuite
## `--house-rule=<name>` (block 17): dph and floor modes play every table of
## the rule's game under it, so a rule's effect can be measured on its own.

const SEED: int = 4242

var _config: TuneConfig = TuneConfig.load_default()


func _parse(args: Array[String]) -> SimOptions:
	return SimOptions.parse(PackedStringArray(args))


func _fingerprint(result: SessionResult) -> Array:
	return [result.net, result.heat, result.hands, result.staked]


func _session(game: GameKind.Kind, rule: String) -> SessionResult:
	return SessionRunner.run(
		_config, StraightFlatBot.new(), game, TableStakes.Kind.HIGH, 1, 60, SEED,
		SessionRunner.DEEP_BANKROLL, rule
	)


func test_the_flag_names_a_rule() -> void:
	assert_str(_parse([]).house_rule).is_empty()
	assert_str(_parse(["--house-rule=bust_23"]).house_rule).is_equal("bust_23")


func test_an_unknown_rule_is_refused() -> void:
	var options: SimOptions = _parse(["--house-rule=no_such_rule", "--sessions=1"])
	assert_array(SimRun.variants_of(options)).is_empty()


func test_a_rule_for_a_game_not_played_is_refused() -> void:
	var options: SimOptions = _parse(["--house-rule=bust_23", "--games=baccarat", "--sessions=1"])
	assert_array(SimRun.variants_of(options)).is_empty()
	var fits: SimOptions = _parse(["--house-rule=bust_23", "--games=blackjack", "--sessions=1"])
	assert_array(SimRun.variants_of(fits)).is_not_empty()
	var any: SimOptions = _parse(["--house-rule=no_side_bets", "--games=baccarat", "--sessions=1"])
	assert_array(SimRun.variants_of(any)).is_not_empty()


func test_run_mode_refuses_the_flag() -> void:
	# A run rolls its own rules onto the map.
	var options: SimOptions = _parse(["--mode=run", "--house-rule=bust_23", "--sessions=1"])
	assert_array(SimRun.variants_of(options)).is_empty()


func test_a_session_plays_under_the_rule() -> void:
	var plain: SessionResult = _session(GameKind.Kind.BLACKJACK, "")
	var ruled: SessionResult = _session(GameKind.Kind.BLACKJACK, "bust_23")
	assert_array(_fingerprint(ruled)).is_not_equal(_fingerprint(plain))


func test_the_rule_leaves_other_games_alone() -> void:
	var plain: SessionResult = _session(GameKind.Kind.BACCARAT, "")
	var ruled: SessionResult = _session(GameKind.Kind.BACCARAT, "bust_23")
	assert_array(_fingerprint(ruled)).is_equal(_fingerprint(plain))


func test_a_floor_plays_under_the_rule() -> void:
	var results: Array[Array] = []
	for rule: String in ["", "bust_23"]:
		var result: FloorResult = FloorRunner.run(
			_config, "straight_flat", GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, 1,
			SimOptions.DEFAULT_BANKROLL, SEED, [], rule
		)
		results.append([result.bankroll, result.hands])
	assert_array(results[1]).is_not_equal(results[0])


func test_the_report_runs_with_the_flag() -> void:
	var options: SimOptions = _parse(
		["--house-rule=aces_high", "--games=high_low", "--bots=straight_flat", "--sessions=4"]
	)
	assert_object(SimRun.dollars_per_heat(options)).is_not_null()


func test_a_string_override_needs_no_quotes() -> void:
	var config: SimConfig = SimConfig.from_default()
	assert_bool(config.add_override("signatures.boss_house_rule=bust_23")).is_true()
	var variants: Array[SimVariant] = config.variants()
	assert_str(variants[0].config.get_string("signatures", "boss_house_rule")).is_equal("bust_23")
