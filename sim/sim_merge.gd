extends SceneTree
## Merges shard JSON files written by sim_main.gd and prints the report.
## Usage: godot --headless -s res://sim/sim_merge.gd -- shard0.json shard1.json ...


func _init() -> void:
	var dollars: SimReport = SimReport.new()
	var floors: FloorReport = FloorReport.new()
	var is_floor: bool = false
	for path: String in OS.get_cmdline_user_args():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("sim_merge: cannot read %s" % path)
			quit(1)
			return
		var saved: Dictionary = parsed
		is_floor = saved.get("kind", "") == "floor"
		if is_floor:
			floors.merge(FloorReport.from_dict(saved))
		else:
			dollars.merge(SimReport.from_dict(saved))
	print(floors.format() if is_floor else dollars.format())
	quit(0)
