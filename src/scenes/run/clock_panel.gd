class_name ClockPanel
extends PanelContainer
## Which floor this is and its hand clock (spec §6.1), pinned top left of a
## floor screen: "27 hands left of 60" over a bar that runs down.

var _title: Label
var _left: Label
var _total: Label
var _bar: ShareBar


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 5
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	rotation_degrees = -1.5
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_title = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	row.add_child(Icons.rect("icons/clock", 16.0, Palette.CREAM))
	_left = UiKit.label("", Fonts.Face.TITLE, 18, Palette.CREAM)
	row.add_child(_left)
	_total = UiKit.label("", Fonts.Face.LABEL, 13, Palette.MUTED)
	row.add_child(_total)
	_bar = ShareBar.new(Vector2(150.0, 6.0), Palette.CREAM, false)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)


func refresh(hud: FloorHudVM) -> void:
	_title.text = hud.floor_title()
	_left.text = hud.hands_left_text()
	_total.text = hud.hands_total_text()
	_bar.show_share(hud.hands_share())
