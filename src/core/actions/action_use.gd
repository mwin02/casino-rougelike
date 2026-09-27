class_name ActionUse
extends RefCounted
## One action taken in a hand. HandHeat prices it as it lands.

var action: ActionKind.Kind
## The round's window_number when it was taken.
var window_number: int
## The cards it targeted, if any.
var card_ids: Array[int]


func _init(p_action: ActionKind.Kind, p_window_number: int, p_card_ids: Array[int]) -> void:
	action = p_action
	window_number = p_window_number
	card_ids = p_card_ids
