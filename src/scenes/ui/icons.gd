class_name Icons
extends RefCounted
## The screen's small symbols: white art, tinted where it's drawn. A Choice
## names its icon; this finds the art.

const HEAT: String = "icons/heat"
## Hearts and diamonds are drawn in this; every other icon in the button's ink.
const RED: Color = Palette.LOSS


## The art for a Choice's icon, or null for none.
static func of(icon: String) -> Texture2D:
	return load(Choice.icon_path(icon)) if not icon.is_empty() else null


## Puts a choice's icon on its button, at size pixels.
static func put(button: Button, icon: String, size: int) -> void:
	if icon.is_empty():
		return
	button.icon = of(icon)
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 8)
	if icon.ends_with("hearts") or icon.ends_with("diamonds"):
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			button.add_theme_color_override(state, RED)


## "+12" beside a small flame: a heat cost without the word.
static func heat(text: String, font_size: int, ink: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	var flame: TextureRect = TextureRect.new()
	flame.texture = of(HEAT)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flame.custom_minimum_size = Vector2(font_size, font_size)
	flame.modulate = ink
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flame)
	row.add_child(UiKit.label(text, Fonts.Face.NUMBER, font_size, ink))
	return row
