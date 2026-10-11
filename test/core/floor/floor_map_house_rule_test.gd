extends GdUnitTestSuite
## House rules on the floor map (spec §5.2): from a set floor on, each table
## has a chance to play under a house rule that fits its game. The rules
## come from their own stream, so they never move the map or any other draw.

const SEEDS: int = 40
const RULED_FLOOR: int = 2

var _config: TuneConfig = TuneConfig.load_default()


func _with_chance(percent: int) -> TuneConfig:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	var old: String = "house_rule_pct=%d" % _config.get_int("map", "house_rule_pct")
	assert_bool(text.contains(old)).is_true()
	return TuneConfig.parse(text.replace(old, "house_rule_pct=%d" % percent))


func _map(config: TuneConfig, run_seed: int, floor_number: int) -> FloorMap:
	var rng: GameRng = GameRng.new(run_seed)
	var map: FloorMap = FloorMap.generate(config, floor_number, rng.stream(GameRng.Stream.FLOOR))
	map.roll_house_rules(config, floor_number, rng.stream(GameRng.Stream.HOUSE_RULES))
	return map


func _tables(map: FloorMap) -> Array[Table]:
	var tables: Array[Table] = []
	for node: MapNode in map.nodes:
		tables.append_array(node.tables)
	return tables


## The map with every table's rule blanked, as saved.
func _without_rules(map: FloorMap) -> Dictionary:
	for table: Table in _tables(map):
		table.house_rule = ""
	return map.to_dict()


func test_at_no_chance_no_table_has_a_rule() -> void:
	var config: TuneConfig = _with_chance(0)
	for run_seed: int in SEEDS:
		for table: Table in _tables(_map(config, run_seed, RULED_FLOOR)):
			assert_str(table.house_rule).is_empty()


func test_at_full_chance_every_table_has_a_rule_that_fits_its_game() -> void:
	var config: TuneConfig = _with_chance(100)
	for run_seed: int in SEEDS:
		for table: Table in _tables(_map(config, run_seed, RULED_FLOOR)):
			assert_bool(config.has_house_rule(table.house_rule)).is_true()
			var game: String = config.house_rule_game(table.house_rule)
			assert_bool(
				game == TuneSchema.ANY_GAME or game == GameKind.config_section(table.game)
			).is_true()
			assert_object(table.rules_config(config)).is_not_same(config)


func test_every_rule_in_the_file_turns_up() -> void:
	var config: TuneConfig = _with_chance(100)
	var seen: Dictionary[String, bool] = {}
	for run_seed: int in SEEDS:
		for table: Table in _tables(_map(config, run_seed, RULED_FLOOR)):
			seen[table.house_rule] = true
	assert_array(seen.keys()).contains_exactly_in_any_order(config.house_rules())


func test_floors_before_the_first_ruled_floor_have_none() -> void:
	var config: TuneConfig = _with_chance(100)
	var first: int = config.get_int("map", "house_rule_from_floor")
	# §5.2: floor 1 is the baseline.
	assert_int(first).is_greater(1)
	for floor_number: int in range(1, first):
		for run_seed: int in SEEDS:
			for table: Table in _tables(_map(config, run_seed, floor_number)):
				assert_str(table.house_rule).is_empty()


func test_a_part_chance_rules_some_tables_and_not_others() -> void:
	var config: TuneConfig = _with_chance(50)
	var ruled: int = 0
	var total: int = 0
	for run_seed: int in SEEDS:
		for table: Table in _tables(_map(config, run_seed, RULED_FLOOR)):
			total += 1
			ruled += int(not table.house_rule.is_empty())
	assert_float(float(ruled) / total).is_between(0.35, 0.65)


func test_rules_never_change_the_map_or_its_tables() -> void:
	var plain: TuneConfig = _with_chance(0)
	var ruled: TuneConfig = _with_chance(100)
	for run_seed: int in SEEDS:
		assert_dict(_without_rules(_map(ruled, run_seed, RULED_FLOOR))).is_equal(
			_map(plain, run_seed, RULED_FLOOR).to_dict()
		)


func test_the_same_seed_rolls_the_same_rules() -> void:
	var config: TuneConfig = _with_chance(50)
	for run_seed: int in SEEDS:
		assert_dict(_map(config, run_seed, RULED_FLOOR).to_dict()).is_equal(
			_map(config, run_seed, RULED_FLOOR).to_dict()
		)


func test_no_chance_and_early_floors_draw_nothing() -> void:
	var fresh: int = GameRng.new(7).stream(GameRng.Stream.HOUSE_RULES).state
	for case: Array in [[_with_chance(0), RULED_FLOOR], [_with_chance(100), 1]]:
		var config: TuneConfig = case[0]
		var floor_number: int = case[1]
		var rng: GameRng = GameRng.new(7)
		var map: FloorMap = FloorMap.generate(
			config, floor_number, rng.stream(GameRng.Stream.FLOOR)
		)
		map.roll_house_rules(config, floor_number, rng.stream(GameRng.Stream.HOUSE_RULES))
		assert_int(rng.stream(GameRng.Stream.HOUSE_RULES).state).is_equal(fresh)


## Passes each floor at its quota and takes the first elevator option.
func _climb(run: Run, floor_number: int) -> void:
	while run.state.floor_number < floor_number:
		run.state.bankroll = maxi(run.state.bankroll, run.floor.quota)
		run.floor.cash_out()
		run.floor.check_quota()
		run.floor.finish()
		run.end_floor()
		run.ride(0)


func test_rules_move_nothing_else_in_a_run() -> void:
	# Later maps, watched tables and elevator options are the same at any
	# chance: only the tables' rules differ.
	var plain: Run = Run.start(_with_chance(0), 4242)
	var ruled: Run = Run.start(_with_chance(100), 4242)
	for floor_number: int in range(2, 5):
		_climb(plain, floor_number)
		_climb(ruled, floor_number)
		assert_int(ruled.floor.signature.kind).is_equal(plain.floor.signature.kind)
		assert_bool(_tables(ruled.floor.map).all(
			func(table: Table) -> bool: return not table.house_rule.is_empty()
		)).is_true()
		assert_dict(_without_rules(ruled.floor.map)).is_equal(plain.floor.map.to_dict())
