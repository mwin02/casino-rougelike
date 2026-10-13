class_name RunFixture
extends RefCounted
## A run on screen for the floor-screen suites: a RunVM saving to its own
## file, on floor 1 of a hand-made map of three rows. Row 0: a low table
## node; row 1: a shop (lane 0) and deck services (lane 2); row 2: a high
## table node. Quota $140,000.

var config: TuneConfig = TuneConfig.load_default()
var owner: RunVM
var floor: Floor
var path: String


func _init(p_path: String, bankroll: int = 50_000) -> void:
	path = p_path
	SaveStore.clear(path)
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = 17
	owner = RunVM.new(config, seeds, path)
	owner.start()
	var run: Run = owner.run
	run.state.bankroll = bankroll
	var f: FloorFixture = FloorFixture.new()
	var nodes: Array[MapNode] = [
		f.tables(0, 1, [0, 2]),
		f.back_room(1, 0, MapNode.Kind.SHOP, [1]),
		f.back_room(1, 2, MapNode.Kind.DECK_SERVICES, [1]),
		f.tables(2, 1, [], TableStakes.Kind.HIGH),
	]
	floor = Floor.new(
		run.config(), run.state, run.game.deck, run.game.layer, run.kit, run.game.rng,
		FloorMap.from_nodes(3, nodes)
	)
	run.floor = floor


func clear() -> void:
	SaveStore.clear(path)


func saved() -> Run:
	return SaveStore.load_from(config, path)


## Walks through the first table node without sitting, into the shop.
func enter_shop() -> void:
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	owner.step_done()


## Walks through the first table node without sitting, into deck services.
func enter_deck_services() -> void:
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	owner.step_done()


## Walks the whole map without sitting or buying, through the quota check
## into the end shop (or out of the run, when the check is failed).
func enter_end_shop() -> void:
	for at: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1)]:
		floor.enter(floor.map.node_at(at.x, at.y))
		floor.leave()
	owner.step_done()
