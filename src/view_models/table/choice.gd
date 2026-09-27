class_name Choice
extends RefCounted
## One button the table screen draws: its label, whether it can be pressed,
## and the id handed back when it is.

var label: String
var enabled: bool
var id: int


func _init(p_label: String, p_enabled: bool, p_id: int) -> void:
	label = p_label
	enabled = p_enabled
	id = p_id
