class_name FloorBackdrop
extends Control
## The wall behind a floor screen, to the design canvas: a band of panelled
## wall across the top with a brass rail under it, and a lamp's glow. It
## runs past the design frame on both sides.

const SPILL: float = 2000.0
const SEAM: float = 136.0

var _band: float
var _glow: bool


## band is the wall's height; the map's is 76.
func _init(band: float = 76.0, glow: bool = true) -> void:
	_band = band
	_glow = glow
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(DesignFrame.SIZE)


func _draw() -> void:
	draw_rect(Rect2(-SPILL, -SPILL, SPILL * 2.0 + size.x, SPILL + _band), Palette.WALL)
	var x: float = -SPILL + fposmod(SPILL, SEAM) + SEAM - 4.0
	while x < size.x + SPILL:
		draw_rect(Rect2(x, -SPILL, 4.0, SPILL + _band), Color(Palette.GOLD, 0.06))
		x += SEAM
	if _glow:
		for ring: int in 26:
			var reach: float = 1.0 - ring / 26.0
			draw_circle(Vector2(425.0, -10.0), 95.0 * reach, Color(Palette.GOLD, 0.012))
	draw_rect(Rect2(-SPILL, _band, SPILL * 2.0 + size.x, 3.0), Palette.RAIL)
