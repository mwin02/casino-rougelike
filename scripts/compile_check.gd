extends SceneTree
## Loads every project script so typed-warning errors surface even in scripts
## nothing references yet. Exits 1 if any script fails to compile.

const ROOTS: Array[String] = ["res://src", "res://test", "res://sim", "res://scripts"]


func _init() -> void:
	var failed: Array[String] = []
	for root: String in ROOTS:
		for path: String in _collect(root):
			var script: GDScript = load(path) as GDScript
			if script == null or not script.can_instantiate():
				failed.append(path)
	for path: String in failed:
		printerr("compile_check: failed to compile ", path)
	quit(1 if failed.size() > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_collect(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
