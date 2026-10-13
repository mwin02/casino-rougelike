class_name UiKit
extends RefCounted
## Small pieces the table screen's panels share: the dark panel, a rounded
## chip, and labels in the canvas's typefaces.

const PANEL_RADIUS: int = 14
const PANEL_BORDER: Color = Color(Palette.GOLD, 0.28)
const SHADOW: Color = Color(0, 0, 0, 0.35)


## The dark panel: a hairline gold edge, a hard lower lip and a soft shadow.
static func panel(radius: int = PANEL_RADIUS) -> StyleBoxFlat:
	var box: StyleBoxFlat = filled(Palette.PANEL, radius)
	box.set_border_width_all(1)
	box.border_color = PANEL_BORDER
	box.shadow_color = SHADOW
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 5)
	return box


static func filled(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing_size = 0.6
	return box


static func label(text: String, face: Fonts.Face, size: int, color: Color) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.add_theme_font_override("font", Fonts.of(face))
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", color)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return made


## A pill of text on a filled ground, e.g. a tier name.
static func chip(text: String, ground: Color, ink: Color, size: int = 12) -> Label:
	var made: Label = label(text, Fonts.Face.LABEL, size, ink)
	var box: StyleBoxFlat = filled(ground, 9)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	made.add_theme_stylebox_override("normal", box)
	return made


## A rounded button with a hard lower lip: gold for the main action, slate
## otherwise. Disabled, it fades.
static func button(text: String, gold: bool = false, font_size: int = 16) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_override("font", Fonts.of(Fonts.Face.BUTTON))
	made.add_theme_font_size_override("font_size", font_size)
	var ground: Color = Palette.GOLD if gold else Palette.BUTTON
	var lip: Color = Palette.GOLD_EDGE if gold else Palette.WELL
	var ink: Color = Palette.PANEL if gold else Palette.CREAM
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = filled(ground, 22)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 8
		box.content_margin_bottom = 10
		box.border_color = lip
		box.border_width_bottom = 1 if state == "pressed" else 4
		if state == "disabled":
			box.bg_color = Color(ground, 0.35)
			box.border_color = Color(lip, 0.35)
		made.add_theme_stylebox_override(state, box)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		made.add_theme_color_override(colour, ink)
	made.add_theme_color_override("font_disabled_color", Color(ink, 0.45))
	return made


## A button that reads as chosen (gold) or not (slate), for option rows.
static func option(text: String, chosen: bool, font_size: int = 13) -> Button:
	var made: Button = button(text, chosen, font_size)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = made.get_theme_stylebox(state)
		box.set_corner_radius_all(10)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 5
		box.content_margin_bottom = 6
		box.border_width_bottom = 3
	return made


## A round slate button holding one symbol, e.g. the bet's minus and plus.
static func round_button(symbol: String, diameter: float = 44.0) -> Button:
	var made: Button = button(symbol, false, roundi(diameter * 0.5))
	made.add_theme_font_override("font", Fonts.of(Fonts.Face.NUMBER))
	made.custom_minimum_size = Vector2(diameter, diameter)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = made.get_theme_stylebox(state)
		box.set_corner_radius_all(roundi(diameter / 2.0))
		box.set_content_margin_all(0)
		box.border_width_bottom = 0
	return made


## A strip of gold tape, as if holding a panel up.
static func tape(at: Vector2, size: Vector2, tilt: float) -> ColorRect:
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(Palette.GOLD, 0.55)
	strip.position = at
	strip.size = size
	strip.rotation_degrees = tilt
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return strip


## A dark panel's column, with the panel's padding set.
static func panel_column(panel: PanelContainer, padding: int, separation: int) -> VBoxContainer:
	var box: StyleBoxFlat = UiKit.panel()
	box.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	panel.add_child(column)
	return column


## Empties a row or column, ready to be filled again.
static func clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
