class_name DesignFrame
extends Control
## An 844×390 frame, the size the design canvas is drawn at, at the top of
## the window and centred across it. While it's in the tree the window
## scales content to that size, so children are placed in the canvas's own
## pixels and text stays sharp. A wider window shows more of whatever is
## drawn behind the frame on both sides; a taller one shows more below it,
## never above, because the canvas cuts things off at its top edge.

const SIZE: Vector2i = Vector2i(844, 390)

var _restore_size: Vector2i


func _enter_tree() -> void:
	var window: Window = get_window()
	_restore_size = window.content_scale_size
	window.content_scale_size = SIZE
	get_viewport().size_changed.connect(_centre)
	_centre()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_centre)
	get_window().content_scale_size = _restore_size


func _centre() -> void:
	size = Vector2(SIZE)
	position = Vector2(roundf((get_viewport_rect().size.x - size.x) / 2.0), 0.0)
