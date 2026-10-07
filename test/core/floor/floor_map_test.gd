extends GdUnitTestSuite
## The floor map (spec §5.2): rows of nodes across lanes, linked to the next
## row in the same or a neighbouring lane, never crossing. The first and
## last rows are table nodes. Each table node is low or high stakes and its
## tables share that type, shown in advance. Every path from the first row
## to the last meets the [map] minimums, and no back room follows another.

const FLOOR: int = 1
const SEEDS: int = 300

var _config: TuneConfig
## One floor-1 map per seed, 0 to SEEDS - 1, shared by the suite.
var _maps: Array[FloorMap] = []


func before() -> void:
	_config = TuneConfig.load_default()
	for run_seed: int in SEEDS:
		_maps.append(_map(run_seed))


func _map(run_seed: int, floor_number: int = FLOOR) -> FloorMap:
	var rng: RandomNumberGenerator = GameRng.new(run_seed).stream(GameRng.Stream.FLOOR)
	return FloorMap.generate(_config, floor_number, rng)


## Every path through the map, by brute force: each a list of nodes.
func _paths(map: FloorMap) -> Array[Array]:
	var paths: Array[Array] = []
	for node: MapNode in map.row(0):
		_walk(map, node, [], paths)
	return paths


func _walk(map: FloorMap, node: MapNode, so_far: Array, paths: Array[Array]) -> void:
	var path: Array = so_far.duplicate()
	path.append(node)
	if node.row == map.row_count() - 1:
		paths.append(path)
		return
	for next: MapNode in map.next_of(node):
		_walk(map, next, path, paths)


func _signature(map: FloorMap) -> String:
	var parts: PackedStringArray = []
	for node: MapNode in map.nodes:
		var games: PackedStringArray = []
		for table: Table in node.tables:
			games.append(str(table.game))
		parts.append(
			"%d.%d:%d/%d[%s]>%s" % [
				node.row, node.lane, node.kind, node.stakes, ",".join(games),
				str(node.next_lanes)
			]
		)
	return " ".join(parts)


func test_rows_hold_a_range_of_nodes_in_distinct_lanes() -> void:
	var rows: int = _config.get_int("map", "rows")
	var lanes: int = _config.get_int("map", "lanes")
	var per_row: Array[int] = _config.get_int_list("map", "nodes_per_row")
	for run_seed: int in SEEDS:
		var map: FloorMap = _maps[run_seed]
		assert_int(map.row_count()).is_equal(rows)
		for r: int in rows:
			var seen: Array[int] = []
			for node: MapNode in map.row(r):
				assert_int(node.row).is_equal(r)
				assert_int(node.lane).is_between(0, lanes - 1)
				assert_bool(node.lane in seen).is_false()
				seen.append(node.lane)
			assert_int(seen.size()).is_between(per_row[0], per_row[1])


func test_the_first_and_last_rows_are_table_nodes() -> void:
	for run_seed: int in SEEDS:
		var map: FloorMap = _maps[run_seed]
		for r: int in [0, map.row_count() - 1]:
			for node: MapNode in map.row(r):
				assert_int(node.kind).is_equal(MapNode.Kind.TABLES)


func test_links_go_one_row_up_to_a_neighbouring_lane_and_never_cross() -> void:
	for run_seed: int in SEEDS:
		var map: FloorMap = _maps[run_seed]
		var last: int = map.row_count() - 1
		for node: MapNode in map.nodes:
			if node.row == last:
				assert_array(node.next_lanes).is_empty()
				continue
			assert_array(node.next_lanes).is_not_empty()
			for lane: int in node.next_lanes:
				assert_object(map.node_at(node.row + 1, lane)).is_not_null()
				assert_int(absi(lane - node.lane)).is_less_equal(1)
			for other: MapNode in map.row(node.row):
				if other.lane <= node.lane:
					continue
				for a: int in node.next_lanes:
					for b: int in other.next_lanes:
						assert_bool(a > b).override_failure_message(
							"seed %d: links from row %d cross" % [run_seed, node.row]
						).is_false()


func test_every_node_past_the_first_row_is_reachable() -> void:
	for run_seed: int in SEEDS:
		var map: FloorMap = _maps[run_seed]
		var reached: Array[MapNode] = []
		for path: Array in _paths(map):
			for node: MapNode in path:
				if node not in reached:
					reached.append(node)
		assert_int(reached.size()).is_equal(map.nodes.size())


func test_every_path_meets_the_minimums() -> void:
	var min_tables: int = _config.get_int("map", "min_tables_per_path")
	var min_high: int = _config.get_int("map", "min_high_per_path")
	var min_low: int = _config.get_int("map", "min_low_per_path")
	var min_back: int = _config.get_int("map", "min_back_room_per_path")
	for run_seed: int in SEEDS:
		for path: Array in _paths(_maps[run_seed]):
			var tables: int = 0
			var high: int = 0
			var back: int = 0
			var back_twice: bool = false
			var previous_back: bool = false
			for node: MapNode in path:
				if node.kind == MapNode.Kind.TABLES:
					tables += 1
					if node.stakes == TableStakes.Kind.HIGH:
						high += 1
				else:
					back += 1
					back_twice = back_twice or previous_back
				previous_back = node.kind != MapNode.Kind.TABLES
			var message: String = "seed %d" % run_seed
			assert_int(tables).override_failure_message(message).is_greater_equal(min_tables)
			assert_int(high).override_failure_message(message).is_greater_equal(min_high)
			assert_int(tables - high).override_failure_message(message).is_greater_equal(min_low)
			assert_int(back).override_failure_message(message).is_greater_equal(min_back)
			assert_bool(back_twice).override_failure_message(message).is_false()


func test_a_table_node_offers_tables_of_its_stakes_at_the_floor_range() -> void:
	var per_node: Array[int] = _config.get_int_list("map", "tables_per_node")
	for run_seed: int in 50:
		for node: MapNode in _map(run_seed, 3).nodes:
			if node.kind != MapNode.Kind.TABLES:
				assert_array(node.tables).is_empty()
				continue
			assert_int(node.tables.size()).is_between(per_node[0], per_node[1])
			for table: Table in node.tables:
				var expected: Table = Table.from_config(_config, table.game, node.stakes, 3)
				assert_int(table.stakes).is_equal(node.stakes)
				assert_int(table.floor_number).is_equal(3)
				assert_int(table.table_min).is_equal(expected.table_min)
				assert_int(table.table_max).is_equal(expected.table_max)


func test_maps_roll_both_stakes_both_back_rooms_and_every_game() -> void:
	var stakes: Array[TableStakes.Kind] = []
	var kinds: Array[MapNode.Kind] = []
	var games: Array[GameKind.Kind] = []
	for run_seed: int in 50:
		for node: MapNode in _maps[run_seed].nodes:
			if node.kind not in kinds:
				kinds.append(node.kind)
			if node.kind == MapNode.Kind.TABLES and node.stakes not in stakes:
				stakes.append(node.stakes)
			for table: Table in node.tables:
				if table.game not in games:
					games.append(table.game)
	assert_int(stakes.size()).is_equal(TableStakes.Kind.size())
	assert_int(kinds.size()).is_equal(MapNode.Kind.size())
	assert_int(games.size()).is_equal(GameKind.Kind.size())


func test_the_same_seed_gives_the_same_map() -> void:
	assert_str(_signature(_map(42))).is_equal(_signature(_map(42)))
	assert_str(_signature(_map(42))).is_not_equal(_signature(_map(43)))
