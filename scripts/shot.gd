extends SceneTree
## Saves a picture of a scene, for checking a screen by eye from the command
## line. Optional steps run in order before the picture is taken, each the
## name of a method on the scene's root, with whole-number arguments after
## colons: _on_sit_down, _on_play:1.
##   godot --path . -s scripts/shot.gd -- <res://scene.tscn> <out.png> [step ...]
## Needs a display (not --headless).

const FRAMES: int = 20


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("shot: usage: -- <res://scene.tscn> <out.png> [step ...]")
		quit(1)
		return
	var packed: PackedScene = load(args[0])
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _wait()
	for step: String in args.slice(2):
		var parts: PackedStringArray = step.split(":")
		var values: Array[int] = []
		for part: String in parts.slice(1):
			values.append(part.to_int())
		scene.callv(parts[0], values)
		await _wait(3)
	await _wait()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()


func _wait(frames: int = FRAMES) -> void:
	for i: int in frames:
		await process_frame
