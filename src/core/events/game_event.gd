class_name GameEvent
extends RefCounted
## One thing that happened in the run. data holds plain values only (numbers,
## strings, arrays, dictionaries) so the event can be saved.

var seq: int
var kind: StringName
var data: Dictionary


func _init(p_seq: int, p_kind: StringName, p_data: Dictionary) -> void:
	seq = p_seq
	kind = p_kind
	data = p_data


func to_dict() -> Dictionary:
	return {"seq": seq, "kind": String(kind), "data": data.duplicate(true)}


static func from_dict(saved: Dictionary) -> GameEvent:
	var seq_value: int = saved["seq"]
	var kind_name: String = saved["kind"]
	var saved_data: Dictionary = saved["data"]
	return GameEvent.new(seq_value, StringName(kind_name), saved_data.duplicate(true))
