extends SceneTree
## Merges shard JSON files written by sim_main.gd and prints the report.
## Usage: godot --headless -s res://sim/sim_merge.gd -- shard0.json shard1.json ...


func _init() -> void:
	var dollars: SimReport = SimReport.new()
	var floors: FloorReport = FloorReport.new()
	var runs: RunReport = RunReport.new()
	var kind: String = ""
	for path: String in OS.get_cmdline_user_args():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("sim_merge: cannot read %s" % path)
			quit(1)
			return
		var saved: Dictionary = parsed
		kind = saved.get("kind", "")
		match kind:
			"floor":
				floors.merge(FloorReport.from_dict(saved))
			"run":
				runs.merge(RunReport.from_dict(saved))
			_:
				dollars.merge(SimReport.from_dict(saved))
	match kind:
		"floor":
			print(floors.format())
		"run":
			print(runs.format())
		_:
			print(dollars.format())
	quit(0)
