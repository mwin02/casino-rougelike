class_name MapNodeView
extends RefCounted
## One node as the floor map draws it: where it is, what it is, how it
## stands to the player's walk, and its links to the next row.

enum Look { LOW, HIGH, SHOP, DECK }
enum Status {
	## The node the player last left.
	CURRENT,
	## Walked earlier.
	VISITED,
	## One step away.
	REACHABLE,
	## Further on, and still on a route from here.
	AHEAD,
	## Behind, or no longer on any route.
	PAST,
}

var row: int
var lane: int
var look: Look
## "HIGH · 3", "SHOP".
var tag: String
var status: Status
## The pit boss watches a table here (spec §7.5).
var watched: bool
var selected: bool
var next_lanes: Array[int]


func _init(node: MapNode, p_status: Status, p_selected: bool) -> void:
	row = node.row
	lane = node.lane
	status = p_status
	selected = p_selected
	next_lanes = node.next_lanes
	match node.kind:
		MapNode.Kind.SHOP:
			look = Look.SHOP
			tag = "SHOP"
		MapNode.Kind.DECK_SERVICES:
			look = Look.DECK
			tag = "DECK"
		_:
			look = Look.HIGH if node.is_high_stakes() else Look.LOW
			tag = "%s · %d" % ["HIGH" if node.is_high_stakes() else "LOW", node.tables.size()]
	watched = node.tables.any(func(table: Table) -> bool: return table.watched)
