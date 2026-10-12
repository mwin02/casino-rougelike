extends SceneTree
## Saves a picture of a scene, for checking a screen by eye from the command
## line. Optional taps, as x,y in the scene's own pixels, are made in order
## before the picture is taken:
##   godot --path . -s scripts/shot.gd -- <res://scene.tscn> <out.png> [x,y ...]
## Needs a display (not --headless).

const FRAMES: int = 20


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("shot: usage: -- <res://scene.tscn> <out.png> [x,y ...]")
		quit(1)
		return
	var packed: PackedScene = load(args[0])
	root.add_child(packed.instantiate())
	await _wait()
	for tap: String in args.slice(2):
		var at: Vector2 = Vector2(tap.get_slice(",", 0).to_float(), tap.get_slice(",", 1).to_float())
		for pressed: bool in [true, false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = root.get_final_transform() * at
			click.global_position = click.position
			Input.parse_input_event(click)
			await _wait(3)
	await _wait()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()


func _wait(frames: int = FRAMES) -> void:
	for i: int in frames:
		await process_frame
