class_name DesignFrame
extends Control
## A frame 844 wide and at least 390 tall, the size the design canvas is
## drawn at, at the top of the window and centred across it. While it's in
## the tree the window scales content to that size, so children are placed
## in the canvas's own pixels and text stays sharp. A wider window shows more
## of whatever is drawn behind the frame on both sides. In a taller one the
## frame grows downward (never above: the canvas cuts things off at its top
## edge), and its `resized` signal lets a scene keep things on the bottom.
##
## The canvas keeps a 44-pixel gutter down each side for a phone's notch or
## island. Where the screen's own safe area is wider than that, the content
## is scaled down a little so the gutters cover it.

const SIZE: Vector2i = Vector2i(844, 390)
const GUTTER: float = 44.0

var _restore_size: Vector2i
## The window size the content scale was last worked out for.
var _fitted_to: Vector2i = Vector2i(-1, -1)


func _enter_tree() -> void:
	_restore_size = get_window().content_scale_size
	get_viewport().size_changed.connect(_lay_out)
	_lay_out()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_lay_out)
	get_window().content_scale_size = _restore_size


## Sets the window's content scale when its size changes, then places the
## frame in the view that gives.
func _lay_out() -> void:
	var window: Window = get_window()
	if window.size != _fitted_to:
		_fitted_to = window.size
		window.content_scale_size = Vector2i(_design_width(window), SIZE.y)
	var view: Vector2 = get_viewport_rect().size
	var units: float = view.x / maxf(window.size.x, 1.0)
	size = Vector2(SIZE.x, maxf(SIZE.y, view.y - _insets(window).y * units))
	position = Vector2(roundf((view.x - size.x) / 2.0), 0.0)


## The design width to scale to: 844, or wider where the screen's safe area
## is narrower than the canvas's gutters allow for.
func _design_width(window: Window) -> int:
	var between: float = SIZE.x - GUTTER * 2.0
	var clear: float = maxf(window.size.x - _insets(window).x * 2.0, 1.0)
	return maxi(SIZE.x, ceili(between * window.size.x / clear))


## The screen's unsafe margin at the sides (x) and the bottom (y), in screen
## pixels. Nothing off a phone, where the safe area is the whole display.
func _insets(window: Window) -> Vector2:
	if DisplayServer.get_name() not in ["iOS", "Android"]:
		return Vector2.ZERO
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var screen: Vector2 = Vector2(window.size)
	var side: float = maxf(safe.position.x, screen.x - safe.end.x)
	return Vector2(maxf(side, 0.0), maxf(screen.y - safe.end.y, 0.0))
