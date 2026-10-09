class_name FloorFixture
extends RefCounted
## Builds floors on hand-made maps for the floor suites. Table nodes hold
## one High or Low table of their stakes on floor 1 (low $1,000–4,000, high
## $5,000–20,000; quota $140,000).

const SEED: int = 99

var config: TuneConfig = TuneConfig.load_default()
var deck: Deck = Deck.standard(20)
var layer: ManipulationLayer = ManipulationLayer.new()
var kit: ActionKit = ActionKit.everything()
var rng: GameRng = GameRng.new(SEED)
var run: RunState


func _init(bankroll: int = 50_000) -> void:
	run = RunState.new_run(config)
	run.bankroll = bankroll


func tables(
	row: int, lane: int, next_lanes: Array[int], stakes: TableStakes.Kind = TableStakes.Kind.LOW
) -> MapNode:
	var node: MapNode = MapNode.new(row, lane, MapNode.Kind.TABLES)
	node.stakes = stakes
	node.tables.append(Table.from_config(config, GameKind.Kind.HIGH_LOW, stakes, 1))
	node.next_lanes = next_lanes
	return node


func back_room(row: int, lane: int, kind: MapNode.Kind, next_lanes: Array[int]) -> MapNode:
	var node: MapNode = MapNode.new(row, lane, kind)
	node.next_lanes = next_lanes
	return node


## A floor on nodes; rows is one past the last node's row.
func floor_on(nodes: Array[MapNode], signature: FloorSignature = null) -> Floor:
	var rows: int = 0
	for node: MapNode in nodes:
		rows = maxi(rows, node.row + 1)
	return Floor.new(
		config, run, deck, layer, kit, rng, FloorMap.from_nodes(rows, nodes), signature
	)


## Row 0: a low table node; row 1: a shop and a deck-services node; row 2:
## a high table node.
func three_rows() -> Floor:
	return floor_on([
		tables(0, 1, [0, 2]),
		back_room(1, 0, MapNode.Kind.SHOP, [1]),
		back_room(1, 2, MapNode.Kind.DECK_SERVICES, [1]),
		tables(2, 1, [], TableStakes.Kind.HIGH),
	])


## Sits at the node's first table and plays count hands at its minimum.
static func play(floor: Floor, count: int) -> TableSession:
	var session: TableSession = floor.session if floor.session != null else floor.sit(0)
	for i: int in count:
		session.start_hand(session.table.table_min)
		TableSessionFixture.play_out(session)
		session.finish_hand()
	return session
