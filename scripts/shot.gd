extends SceneTree
## Saves a picture of a scene, for checking a screen by eye from the command
## line: godot --path . -s scripts/shot.gd -- <res://scene.tscn> <out.png>
## Needs a display (not --headless).

const FRAMES: int = 20


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("shot: usage: -- <res://scene.tscn> <out.png>")
		quit(1)
		return
	var packed: PackedScene = load(args[0])
	root.add_child(packed.instantiate())
	for i: int in FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
