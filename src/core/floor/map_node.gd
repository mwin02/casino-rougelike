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
