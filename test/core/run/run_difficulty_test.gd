extends GdUnitTestSuite
## A run's difficulty (spec §6.3, §6.4): the level sets every floor's quota
## and stakes and the run's prices, and the run resumes at it.

const PATH: String = "user://test_run_difficulty.bin"
const SEED: int = 4242
const EASY: int = 0

var _config: TuneConfig = TuneConfig.load_default()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Passes each floor at its quota and takes the first option at each
## elevator, up to floor_number.
func _climb(run: Run, floor_number: int) -> void:
	while run.state.floor_number < floor_number:
		run.state.bankroll = maxi(run.state.bankroll, run.floor.quota)
		run.floor.cash_out()
		run.floor.check_quota()
		run.floor.finish()
		run.end_floor()
		run.ride(0)


func test_a_run_starts_at_the_configs_level() -> void:
	assert_int(Run.start(_config, SEED).state.difficulty).is_equal(_config.difficulty())


func test_a_run_at_easy_uses_its_quotas_and_stakes_on_every_floor() -> void:
	var easy: TuneConfig = _config.for_difficulty(EASY)
	var run: Run = Run.start(_config, SEED, null, EASY)
	assert_int(run.state.difficulty).is_equal(EASY)
	for floor_number: int in range(1, TuneSchema.FLOORS + 1):
		_climb(run, floor_number)
		var i: int = floor_number - 1
		assert_int(run.floor.quota).is_equal(easy.get_int_list("floors", "quotas")[i])
		for node: MapNode in run.floor.map.nodes:
			for table: Table in node.tables:
				var prefix: String = "high_stakes" if node.is_high_stakes() else "low_stakes"
				assert_int(table.table_min).is_equal(easy.get_int_list("floors", prefix + "_min")[i])
				assert_int(table.table_max).is_equal(easy.get_int_list("floors", prefix + "_max")[i])


## Prices are the level's quota × its run multiplier (§6.4): Easy at ×1.5
## here, at floor 2's end shop.
func test_a_run_at_easy_prices_at_easy() -> void:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	var at: int = text.find("run_price_pct=100", text.find("[difficulty_0]"))
	text = text.substr(0, at) + "run_price_pct=150" + text.substr(at + "run_price_pct=100".length())
	var config: TuneConfig = TuneConfig.parse(text)
	var run: Run = Run.start(config, SEED, null, EASY)
	_climb(run, 2)
	run.state.bankroll = run.floor.quota
	run.floor.cash_out()
	run.floor.check_quota()
	var quota: int = config.for_difficulty(EASY).get_int_list("floors", "quotas")[1]
	var tape_pct: int = config.get_int("shop", "masking_tape_pct")
	assert_int(run.floor.shop.tape_price()).is_equal(ShopPricing.new(quota, 100, 150).price(tape_pct))


func test_a_run_at_an_unknown_level_is_refused() -> void:
	assert_object(Run.start(_config, SEED, null, 1)).is_null()


func test_the_level_survives_save_and_resume() -> void:
	var run: Run = Run.start(_config, SEED, null, EASY)
	_climb(run, 2)
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	var resumed: Run = SaveStore.load_from(_config, PATH)
	assert_int(resumed.state.difficulty).is_equal(EASY)
	var easy_quota: int = _config.for_difficulty(EASY).get_int_list("floors", "quotas")[1]
	assert_int(resumed.floor.quota).is_equal(easy_quota)
	assert_dict(resumed.to_dict()).is_equal(run.to_dict())
	_climb(run, 3)
	_climb(resumed, 3)
	assert_dict(resumed.to_dict()).is_equal(run.to_dict())


func test_a_save_at_an_unknown_level_is_refused() -> void:
	var saved: Dictionary = Run.start(_config, SEED).to_dict()
	var state: Dictionary = saved["state"]
	state["difficulty"] = 1
	assert_object(SaveStore.from_saved(saved, _config)).is_null()
