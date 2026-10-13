class_name Choice
extends RefCounted
## One button the table screen draws: its label, whether it can be pressed,
## the id handed back when it is, and whether it's the option now chosen.

var label: String
var enabled: bool
var id: int
var selected: bool
## A second, smaller line for the button, e.g. a heat cost: "+12".
var detail: String = ""
## The art the real table draws beside the label, as a path under
## res://assets without its ending: "icons/nudge". Empty for none.
var icon: String = ""


func _init(p_label: String, p_enabled: bool, p_id: int, p_selected: bool = false) -> void:
	label = p_label
	enabled = p_enabled
	id = p_id
	selected = p_selected


## Where an icon's art is: "res://assets/icons/nudge.svg".
static func icon_path(p_icon: String) -> String:
	return "res://assets/%s.svg" % p_icon
