class_name DeckEdit
extends RefCounted
## One permanent change to the owned deck. Each edit raises the heat floor
## (spec §4.2); edits count cumulatively. Marks are not edits.

enum Kind {
	REMOVE,
	ADD,
	REFORGE_RUMMAGE,
	REFORGE_TOUCH_UP,
	REFORGE_FULL,
	COLD_SEAL,
	PERMANENT_INK,
}

const REFORGE_KINDS: Array[Kind] = [Kind.REFORGE_RUMMAGE, Kind.REFORGE_TOUCH_UP, Kind.REFORGE_FULL]
## A manipulation made permanent during a hand (spec §2.3).
const PERMANENT_KINDS: Array[Kind] = [Kind.COLD_SEAL, Kind.PERMANENT_INK]

var kind: Kind
var card_id: int


func _init(p_kind: Kind, p_card_id: int) -> void:
	kind = p_kind
	card_id = p_card_id
