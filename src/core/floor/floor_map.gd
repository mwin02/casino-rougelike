class_name FloorMap
extends RefCounted
## A floor's branching map (spec §5.2). Rows of 2–3 nodes across the lanes;
## each node links to the next row's nodes in its own or a neighbouring
## lane, and links never cross. The first and last rows are table nodes;
## middle rows roll their kind by weight. A table node rolls its stakes type
## and its tables' games, all shown in advance so the route can be planned.
##
## A rolled map is kept only if every path from the first row to the last
## passes the [map] minimums of table nodes (high and low stakes) and back
## rooms, and no back room links to another. Otherwise the shape rolls
## again; the tables are rolled once a shape is kept. House rules are
## rolled onto the tables afterwards from their own stream
## (roll_house_rules), so they never move the map or any other draw.

## Rolls before giving up on the minimums; reached only by a bad config.
const MAX_ATTEMPTS: int = 10000

## Row by row, lane order within a row.
var nodes: Array[MapNode] = []

var _rows: int


static func generate(
	config: TuneConfig, floor_number: int, rng: RandomNumberGenerator
) -> FloorMap:
	var rules: MapRules = MapRules.from_config(config)
	var map: FloorMap = null
	for attempt: int in MAX_ATTEMPTS:
		map = _roll(rules, rng)
		if map._meets(rules):
			break
		if attempt == MAX_ATTEMPTS - 1:
			push_error("FloorMap: no map met the [map] minimums")
	for node: MapNode in map.nodes:
		if node.kind == MapNode.Kind.TABLES:
			_roll_tables(config, rules, floor_number, node, rng)
	return map


## §5.2: from the first ruled floor on, each table has a chance to play
## under a house rule, drawn from those that fit its game. rng is the run's
## HOUSE_RULES stream.
func roll_house_rules(config: TuneConfig, floor_number: int, rng: RandomNumberGenerator) -> void:
	var rules: MapRules = MapRules.from_config(config)
	if rules.house_rule_pct <= 0 or floor_number < rules.house_rule_from_floor:
		return
	for node: MapNode in nodes:
		for table: Table in node.tables:
			_roll_house_rule(config, rules, table, rng)


## A map of hand-made nodes, row by row.
static func from_nodes(rows: int, p_nodes: Array[MapNode]) -> FloorMap:
	var map: FloorMap = FloorMap.new()
	map._rows = rows
	map.nodes = p_nodes
	return map


func to_dict() -> Dictionary:
	var saved_nodes: Array[Dictionary] = []
	for node: MapNode in nodes:
		saved_nodes.append(node.to_dict())
	return {"rows": _rows, "nodes": saved_nodes}


static func from_dict(saved: Dictionary) -> FloorMap:
	var saved_nodes: Array = saved["nodes"]
	var p_nodes: Array[MapNode] = []
	for saved_node: Dictionary in saved_nodes:
		p_nodes.append(MapNode.from_dict(saved_node))
	var rows: int = saved["rows"]
	return from_nodes(rows, p_nodes)


func row_count() -> int:
	return _rows


func row(r: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.row == r:
			result.append(node)
	return result


func node_at(r: int, lane: int) -> MapNode:
	for node: MapNode in nodes:
		if node.row == r and node.lane == lane:
			return node
	return null


func next_of(node: MapNode) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for lane: int in node.next_lanes:
		result.append(node_at(node.row + 1, lane))
	return result


## The map's shape: lanes, kinds, stakes and links. Tables come once a
## shape meets the minimums.
static func _roll(rules: MapRules, rng: RandomNumberGenerator) -> FloorMap:
	var map: FloorMap = FloorMap.new()
	map._rows = rules.rows
	for r: int in rules.rows:
		var lanes: Array[int] = []
		lanes.assign(range(rules.lanes))
		var count: int = rng.randi_range(rules.nodes_per_row[0], rules.nodes_per_row[1])
		while lanes.size() > count:
			lanes.remove_at(rng.randi_range(0, lanes.size() - 1))
		var edge: bool = r == 0 or r == rules.rows - 1
		for lane: int in lanes:
			var kind: MapNode.Kind = MapNode.Kind.TABLES if edge else _roll_kind(rules, rng)
			var node: MapNode = MapNode.new(r, lane, kind)
			if kind == MapNode.Kind.TABLES:
				var high: bool = rng.randi_range(1, 100) <= rules.high_stakes_pct
				node.stakes = TableStakes.Kind.HIGH if high else TableStakes.Kind.LOW
			map.nodes.append(node)
	for r: int in rules.rows - 1:
		map._link(map.row(r), map.row(r + 1), rng)
	return map


static func _roll_kind(rules: MapRules, rng: RandomNumberGenerator) -> MapNode.Kind:
	var roll: int = rng.randi_range(
		1, rules.table_weight + rules.shop_weight + rules.deck_services_weight
	)
	if roll <= rules.table_weight:
		return MapNode.Kind.TABLES
	if roll <= rules.table_weight + rules.shop_weight:
		return MapNode.Kind.SHOP
	return MapNode.Kind.DECK_SERVICES


static func _roll_tables(
	config: TuneConfig,
	rules: MapRules,
	floor_number: int,
	node: MapNode,
	rng: RandomNumberGenerator
) -> void:
	var games: Array = GameKind.Kind.values()
	for i: int in rng.randi_range(rules.tables_per_node[0], rules.tables_per_node[1]):
		var game: GameKind.Kind = games[rng.randi_range(0, games.size() - 1)]
		node.tables.append(Table.from_config(config, game, node.stakes, floor_number))


static func _roll_house_rule(
	config: TuneConfig, rules: MapRules, table: Table, rng: RandomNumberGenerator
) -> void:
	if rng.randi_range(1, 100) > rules.house_rule_pct:
		return
	var fitting: Array[String] = config.house_rules_for(GameKind.config_section(table.game))
	if not fitting.is_empty():
		table.house_rule = fitting[rng.randi_range(0, fitting.size() - 1)]


## Links each node to the next row's nodes within one lane. Where two
## neighbours would cross (lane l to l + 1 and lane l + 1 to l), one of the
## two diagonals is dropped; both nodes keep their straight link.
func _link(from: Array[MapNode], to: Array[MapNode], rng: RandomNumberGenerator) -> void:
	for node: MapNode in from:
		for next: MapNode in to:
			if absi(next.lane - node.lane) <= 1:
				node.next_lanes.append(next.lane)
	for node: MapNode in from:
		var right: MapNode = _in_lane(from, node.lane + 1)
		if right == null or not (node.lane + 1 in node.next_lanes):
			continue
		if not (node.lane in right.next_lanes):
			continue
		if rng.randi_range(0, 1) == 0:
			node.next_lanes.erase(node.lane + 1)
		else:
			right.next_lanes.erase(node.lane)


func _meets(rules: MapRules) -> bool:
	for node: MapNode in nodes:
		for next: MapNode in next_of(node):
			if node.is_back_room() and next.is_back_room():
				return false
	return (
		_fewest(func(n: MapNode) -> bool: return n.kind == MapNode.Kind.TABLES)
			>= rules.min_tables_per_path
		and _fewest(func(n: MapNode) -> bool: return n.is_high_stakes())
			>= rules.min_high_per_path
		and _fewest(
			func(n: MapNode) -> bool: return n.kind == MapNode.Kind.TABLES and not n.is_high_stakes()
		) >= rules.min_low_per_path
		and _fewest(func(n: MapNode) -> bool: return n.is_back_room())
			>= rules.min_back_room_per_path
	)


## The fewest nodes matching counts that any first-to-last path passes.
func _fewest(counts: Callable) -> int:
	var best: Dictionary[MapNode, int] = {}
	for node: MapNode in nodes:
		var own: int = 1 if counts.call(node) else 0
		if node.row == 0:
			best[node] = own
		for next: MapNode in next_of(node):
			var through: int = best[node] + (1 if counts.call(next) else 0)
			if not best.has(next) or through < best[next]:
				best[next] = through
	var fewest: int = -1
	for node: MapNode in row(_rows - 1):
		fewest = best[node] if fewest < 0 else mini(fewest, best[node])
	return fewest


static func _in_lane(row_nodes: Array[MapNode], lane: int) -> MapNode:
	for node: MapNode in row_nodes:
		if node.lane == lane:
			return node
	return null
