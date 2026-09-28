class_name Choice
extends RefCounted
## One button the table screen draws: its label, whether it can be pressed,
## the id handed back when it is, and whether it's the option now chosen.

var label: String
var enabled: bool
var id: int
var selected: bool


func _init(p_label: String, p_enabled: bool, p_id: int, p_selected: bool = false) -> void:
	label = p_label
	enabled = p_enabled
	id = p_id
	selected = p_selected
