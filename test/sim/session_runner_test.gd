extends GdUnitTestSuite
## One measurement session: a bot sits at a clean table on a standard deck
## and plays until its hand count or the session ends (spec §12).

const SEED: int = 4242

var _config: TuneConfig = TuneConfig.load_default()


func _run(
	bot: Bot,
	game: GameKind.Kind,
	hands: int,
	seed: int = SEED,
	bankroll: int = SessionRunner.DEEP_BANKROLL
) -> SessionResult:
	return SessionRunner.run(
		_config, bot, game, TableStakes.Kind.HIGH, 1, hands, seed, bankroll
	)


func _fingerprint(result: SessionResult) -> Array:
	return [result.net, result.heat, result.hands, result.staked, result.end_reason]


func test_the_same_seed_plays_the_same_session() -> void:
	for game: int in GameKind.Kind.values():
		var first: SessionResult = _run(StraightFlatBot.new(), game as GameKind.Kind, 30)
		var second: SessionResult = _run(StraightFlatBot.new(), game as GameKind.Kind, 30)
		assert_array(_fingerprint(second)).is_equal(_fingerprint(first))


func test_different_seeds_play_different_sessions() -> void:
	var nets: Dictionary[int, bool] = {}
	for seed: int in 5:
		nets[_run(BoldBot.new(), GameKind.Kind.BLACKJACK, 10, seed).net] = true
	assert_int(nets.size()).is_greater(1)


func test_every_game_plays_its_hand_count_and_stands_up() -> void:
	for game: int in GameKind.Kind.values():
		var result: SessionResult = _run(StraightFlatBot.new(), game as GameKind.Kind, 25)
		assert_int(result.hands).is_equal(25)
		assert_int(result.end_reason).is_equal(SessionEnd.Reason.STOOD_UP)


func test_straight_flat_costs_no_heat_and_stakes_the_minimum() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.BACCARAT, TableStakes.Kind.HIGH, 1)
	var result: SessionResult = _run(StraightFlatBot.new(), GameKind.Kind.BACCARAT, 25)
	assert_float(result.heat).is_equal(0.0)
	assert_int(result.staked).is_equal(25 * table.table_min)


func test_bold_stakes_the_table_maximum() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.HIGH_LOW, TableStakes.Kind.HIGH, 1)
	var result: SessionResult = _run(BoldBot.new(), GameKind.Kind.HIGH_LOW, 10)
	assert_int(result.staked).is_equal(10 * table.table_max)


func test_a_short_bankroll_goes_broke() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, 1)
	var result: SessionResult = _run(
		BoldBot.new(), GameKind.Kind.BLACKJACK, 500, SEED, table.table_min
	)
	assert_int(result.end_reason).is_equal(SessionEnd.Reason.BROKE)
	assert_int(result.hands).is_less(500)


func test_the_roster_builds_bots_by_name() -> void:
	var bots: Array[Bot] = BotRoster.build(["bold", "straight_flat"])
	assert_int(bots.size()).is_equal(2)
	assert_str(bots[0].bot_name()).is_equal("bold")
	assert_str(bots[1].bot_name()).is_equal("straight_flat")
	assert_bool(BotRoster.names().has("straight_flat")).is_true()
	assert_bool(BotRoster.build(["no_such_bot"]).is_empty()).is_true()
