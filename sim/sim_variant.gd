class_name SimVariant
extends RefCounted
## One config the harness runs: the default file with one value picked for
## each override. The label names those values, or "default".

var label: String
var config: TuneConfig


func _init(p_label: String, p_config: TuneConfig) -> void:
	label = p_label
	config = p_config
