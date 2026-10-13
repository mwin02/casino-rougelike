class_name ShareBar
extends Control
## A bar filled from the left to a share of its width, e.g. the bankroll
## against the quota. A second share can follow the first in stripes, for
## what a purchase would take.

var _fill: Color
var _outlined: bool
var _share: float = 0.0
var _striped: float = 0.0
var _stripe_ink: Color = Palette.TIERS[2]


func _init(p_size: Vector2, fill: Color, outlined: bool = true) -> void:
	custom_minimum_size = p_size
	_fill = fill
	_outlined = outlined
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fills to share, then stripes the striped share after it. Both 0 to 1.
func show_share(share: float, striped: float = 0.0) -> void:
	_share = clampf(share, 0.0, 1.0)
	_striped = clampf(striped, 0.0, 1.0 - _share)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var radius: int = roundi(size.y / 2.0)
	var inner: Rect2 = rect.grow(-2.0) if _outlined else rect
	if _outlined:
		draw_style_box(UiKit.filled(Palette.OUTLINE, radius), rect)
	draw_style_box(UiKit.filled(Palette.WELL, roundi(inner.size.y / 2.0)), inner)
	var filled: float = inner.size.x * _share
	if filled > 0.0:
		var box: StyleBoxFlat = UiKit.filled(_fill, roundi(inner.size.y / 2.0))
		if _share < 1.0:
			box.corner_radius_top_right = 0
			box.corner_radius_bottom_right = 0
		draw_style_box(box, Rect2(inner.position, Vector2(filled, inner.size.y)))
	var x: float = inner.position.x + filled
	var stop: float = x + inner.size.x * _striped
	while x < stop:
		draw_rect(Rect2(x, inner.position.y, minf(3.0, stop - x), inner.size.y), _stripe_ink)
		x += 6.0
