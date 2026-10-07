class_name ItemBonus
extends RefCounted
## Dollars an item added to a hand's net (spec §9): a bonus on a win, or Comp
## Slip's refund. Its own line in the hand summary.

var item: ItemKind.Kind
var dollars: int


func _init(p_item: ItemKind.Kind, p_dollars: int) -> void:
	item = p_item
	dollars = p_dollars
