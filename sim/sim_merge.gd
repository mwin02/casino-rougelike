extends SceneTree
## Merges shard JSON files written by sim_main.gd and prints the report.
## Usage: godot --headless -s res://sim/sim_merge.gd -- shard0.json shard1.json ...


func _init() -> void:
	var report: SimReport = SimReport.new()
	for path: String in OS.get_cmdline_user_args():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			printerr("sim_merge: cannot read %s" % path)
			quit(1)
			return
		var saved: Dictionary = parsed
		report.merge(SimReport.from_dict(saved))
	print(report.format())
	quit(0)
