class_name TrickRow
extends RefCounted
## One row of the Tricks screen's history: what an action found or did this
## hand, and the ways to keep the change if a card still shows one.

var text: String
## The cards the action touched.
var card_ids: Array[int] = []
## Tape, Seal and Ink for the change, or empty when there's none to keep.
var keeps: Array[Choice] = []
## The card the keeps are for, as it reads now.
var keep_card: String = ""


func _init(p_text: String, p_card_ids: Array[int]) -> void:
	text = p_text
	card_ids = p_card_ids
