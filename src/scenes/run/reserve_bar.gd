class_name ReserveBar
extends Control
## The end shop's bankroll as a bar (spec §6.5): gold for what it holds,
## red stripes over the reserve it can't spend, and a tick at the quota
## just passed.

var _money: ReserveMoney


func _init(height: float) -> void:
	custom_minimum_size.y = height
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_money(money: ReserveMoney) -> void:
	_money = money
	queue_redraw()


func _draw() -> void:
	if _money == null:
		return
	var radius: int = roundi(size.y / 2.0)
	draw_style_box(UiKit.filled(Palette.WELL, radius), Rect2(Vector2.ZERO, size))
	var held: float = size.x * _money.bankroll_share()
	draw_style_box(UiKit.filled(Palette.GOLD, radius), Rect2(0.0, 0.0, held, size.y))
	var stop: float = size.x * _money.reserve_share()
	var x: float = 0.0
	while x < stop:
		draw_rect(Rect2(x, 0.0, minf(2.0, stop - x), size.y), Palette.ALERT)
		x += 4.0
	draw_rect(Rect2(size.x * _money.quota_share() - 1.0, 0.0, 2.0, size.y), Palette.CREAM)
