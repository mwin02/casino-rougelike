extends GdUnitTestSuite
## The harness's command-line flags.


func _parse(args: Array[String]) -> SimOptions:
	return SimOptions.parse(PackedStringArray(args))


func test_defaults() -> void:
	var options: SimOptions = _parse([])
	assert_array(options.problems).is_empty()
	assert_int(options.mode).is_equal(SimOptions.Mode.DOLLARS_PER_HEAT)
	assert_array(options.games).contains_exactly(
		[GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW]
	)
	assert_array(options.bots).is_empty()
	assert_int(options.floor_number).is_equal(1)
	assert_int(options.stakes).is_equal(TableStakes.Kind.HIGH)
	assert_int(options.shard_index).is_equal(0)
	assert_int(options.shard_count).is_equal(1)
	assert_int(options.bankroll).is_equal(SimOptions.DEFAULT_BANKROLL)


func test_every_flag() -> void:
	var options: SimOptions = _parse(
		[
			"--mode=floor",
			"--games=baccarat,high_low",
			"--bots=straight_flat,bold",
			"--sessions=50",
			"--hands=12",
			"--floor=3",
			"--stakes=low",
			"--seed=99",
			"--shard=2/4",
			"--bankroll=140000",
			"--out=user://shard.json",
			"--set=blackjack.bet_change_base=0,4",
			"--set=high_low.cut_pct=5",
			"--items=side_pocket,sleight",
		]
	)
	assert_array(options.problems).is_empty()
	assert_int(options.mode).is_equal(SimOptions.Mode.FLOOR)
	assert_array(options.games).contains_exactly(
		[GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW]
	)
	assert_array(options.bots).contains_exactly(["straight_flat", "bold"])
	assert_array(options.items).contains_exactly(
		[ItemKind.Kind.SIDE_POCKET, ItemKind.Kind.SLEIGHT]
	)
	assert_int(options.sessions).is_equal(50)
	assert_int(options.hands).is_equal(12)
	assert_int(options.floor_number).is_equal(3)
	assert_int(options.stakes).is_equal(TableStakes.Kind.LOW)
	assert_int(options.seed).is_equal(99)
	assert_int(options.shard_index).is_equal(2)
	assert_int(options.shard_count).is_equal(4)
	assert_int(options.bankroll).is_equal(140000)
	assert_str(options.out_path).is_equal("user://shard.json")
	assert_array(options.sets).contains_exactly(
		["blackjack.bet_change_base=0,4", "high_low.cut_pct=5"]
	)


func test_shard_splits_session_indices_evenly() -> void:
	var sessions: Array[int] = []
	for index: int in 3:
		var options: SimOptions = _parse(["--sessions=10", "--shard=%d/3" % index])
		sessions.append_array(options.shard_sessions())
	sessions.sort()
	assert_array(sessions).contains_exactly([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])


func test_bad_flags_are_problems() -> void:
	var bad: Array[String] = [
		"--games=poker",
		"--stakes=medium",
		"--mode=other",
		"--sessions=0",
		"--floor=6",
		"--shard=3/3",
		"--shard=x",
		"--sessions=ten",
		"--colour=red",
		"--items=lucky_charm",
		"loose",
	]
	for arg: String in bad:
		assert_bool(_parse([arg]).problems.is_empty()).override_failure_message(arg).is_false()


func test_run_mode() -> void:
	var options: SimOptions = _parse(["--mode=run"])
	assert_array(options.problems).is_empty()
	assert_int(options.mode).is_equal(SimOptions.Mode.RUN)
