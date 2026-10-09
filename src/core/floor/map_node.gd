class_name MapNode
extends RefCounted
## One stop on a floor map (spec §5.2): a table node of 2–3 tables, all of
## one stakes type and shown in advance, or a back-room stop. Events are out
## of V1 (§13).

enum Kind { TABLES, SHOP, DECK_SERVICES }

## 0 is the first row.
var row: int
var lane: int
var kind: Kind
## A table node's stakes type. Unused by back rooms.
var stakes: TableStakes.Kind = TableStakes.Kind.LOW
## A table node's tables; empty for back rooms.
var tables: Array[Table] = []
## Lanes of the linked nodes in the next row; empty on the last row.
var next_lanes: Array[int] = []


func _init(p_row: int, p_lane: int, p_kind: Kind) -> void:
	row = p_row
	lane = p_lane
	kind = p_kind


func is_back_room() -> bool:
	return kind != Kind.TABLES


func is_high_stakes() -> bool:
	return kind == Kind.TABLES and stakes == TableStakes.Kind.HIGH


func to_dict() -> Dictionary:
	var saved_tables: Array[Dictionary] = []
	for table: Table in tables:
		saved_tables.append(table.to_dict())
	return {
		"row": row,
		"lane": lane,
		"kind": kind,
		"stakes": stakes,
		"tables": saved_tables,
		"next_lanes": next_lanes.duplicate(),
	}


static func from_dict(saved: Dictionary) -> MapNode:
	var p_kind: int = saved["kind"]
	var p_row: int = saved["row"]
	var p_lane: int = saved["lane"]
	var node: MapNode = MapNode.new(p_row, p_lane, p_kind as Kind)
	var p_stakes: int = saved["stakes"]
	node.stakes = p_stakes as TableStakes.Kind
	var saved_tables: Array = saved["tables"]
	for saved_table: Dictionary in saved_tables:
		node.tables.append(Table.from_dict(saved_table))
	var saved_lanes: Array = saved["next_lanes"]
	node.next_lanes.assign(saved_lanes)
	return node
