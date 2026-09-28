extends SceneTree
## Harness entry point for one process. Flags after `--` (see SimOptions).
## With --out it writes its shard as JSON for sim_merge.gd; otherwise it
## prints the report. scripts/sim runs several of these and merges them.


func _init() -> void:
	var options: SimOptions = SimOptions.parse(OS.get_cmdline_user_args())
	var saved: Dictionary = {}
	var printed: String = ""
	if options.mode == SimOptions.Mode.FLOOR:
		var floors: FloorReport = SimRun.floors(options)
		if floors != null:
			saved = floors.to_dict()
			printed = floors.format()
	else:
		var report: SimReport = SimRun.dollars_per_heat(options)
		if report != null:
			saved = report.to_dict()
			printed = report.format()
	if saved.is_empty():
		quit(1)
		return
	if options.out_path.is_empty():
		print(printed)
		quit(0)
		return
	var file: FileAccess = FileAccess.open(options.out_path, FileAccess.WRITE)
	if file == null:
		printerr("sim: cannot write %s" % options.out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(saved))
	quit(0)
