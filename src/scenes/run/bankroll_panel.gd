class_name BankrollPanel
extends PanelContainer
## The bankroll against the floor's quota (spec §6.2), pinned top right of a
## floor screen: the amount, a bar toward the quota, and what's left to win.

const WIDTH: float = 212.0

var _amount: Label
var _bar: ShareBar
var _quota: Label
var _gap: Label


func _init() -> void:
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 7
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	rotation_degrees = 1.0
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	top.add_child(_spread(UiKit.label("BANKROLL", Fonts.Face.LABEL, 11, Palette.MUTED)))
	_amount = UiKit.label("", Fonts.Face.NUMBER, 21, Palette.CREAM)
	top.add_child(_amount)
	_bar = ShareBar.new(Vector2(0.0, 10.0), Palette.GOLD)
	column.add_child(_bar)
	var foot: HBoxContainer = HBoxContainer.new()
	column.add_child(foot)
	_quota = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	foot.add_child(_spread(_quota))
	_gap = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	foot.add_child(_gap)


func refresh(hud: FloorHudVM) -> void:
	_amount.text = hud.bankroll_text()
	_bar.show_share(hud.quota_share())
	_quota.text = hud.quota_text()
	_gap.text = hud.gap_text()
	_gap.add_theme_color_override(
		"font_color", Palette.GOLD if hud.at_quota() else Palette.MUTED
	)


## Left-aligned and taking the row's spare width.
func _spread(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
