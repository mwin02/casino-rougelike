class_name MapScreen
extends Control
## The floor map between tables (block U4), to the design canvas: the floor
## and its clock, the bankroll against the quota, run heat, the map's nodes
## and the one picked, and cashing out. Draws a MapVM and forwards presses.

## The run has moved to another screen.
signal moved

var _vm: MapVM
var _frame: DesignFrame
var _clock: ClockPanel
var _bankroll: BankrollPanel
var _heat: RunHeatPanel
var _board: MapBoard
var _node: NodePanel
var _cash_out: Button
var _shed: Label
var _locked: PanelContainer
var _locked_note: Label


func _init(vm: MapVM) -> void:
	_vm = vm
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_frame.add_child(FloorBackdrop.new())
	_clock = ClockPanel.new()
	_clock.position = Vector2(DesignFrame.GUTTER, 10.0)
	_frame.add_child(_clock)
	_bankroll = BankrollPanel.new()
	var right: float = DesignFrame.SIZE.x - DesignFrame.GUTTER
	_bankroll.position = Vector2(right - BankrollPanel.WIDTH, 10.0)
	_frame.add_child(_bankroll)
	_frame.add_child(UiKit.tape(Vector2(right - 146.0, 4.0), Vector2(40.0, 13.0), -4.0))
	var home: Button = UiKit.button("Home", false, 13)
	home.position = Vector2(300.0, 20.0)
	home.pressed.connect(_on_home)
	_frame.add_child(home)
	_heat = RunHeatPanel.new()
	_heat.position = Vector2(DesignFrame.GUTTER, 86.0)
	_frame.add_child(_heat)
	_board = MapBoard.new()
	_board.position = Vector2(128.0, 86.0)
	_board.picked.connect(_on_pick)
	_frame.add_child(_board)
	_frame.add_child(UiKit.tape(Vector2(150.0, 80.0), Vector2(46.0, 14.0), -5.0))
	_frame.add_child(UiKit.tape(Vector2(510.0, 80.0), Vector2(46.0, 14.0), 4.0))
	_node = NodePanel.new()
	_node.position = Vector2(right - NodePanel.SIZE.x, 86.0)
	_node.walk_pressed.connect(_on_walk)
	_frame.add_child(_node)
	_frame.add_child(UiKit.tape(Vector2(right - 132.0, 78.0), Vector2(50.0, 16.0), -3.0))
	_build_cash_out(Rect2(right - NodePanel.SIZE.x, 328.0, NodePanel.SIZE.x, 48.0))
	_refresh()


## Cash out as a gold button once the quota is reached, and before that a
## note of when it opens.
func _build_cash_out(rect: Rect2) -> void:
	_cash_out = UiKit.button("Cash out", true, 17)
	_cash_out.icon = Icons.of("icons/cash_out")
	_cash_out.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cash_out.add_theme_constant_override("icon_max_width", 20)
	for colour: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		_cash_out.add_theme_color_override(colour, Palette.PANEL)
	_cash_out.position = rect.position
	_cash_out.custom_minimum_size = rect.size
	_cash_out.pressed.connect(_on_cash_out)
	_frame.add_child(_cash_out)
	_shed = UiKit.label("", Fonts.Face.NUMBER, 14, Palette.PANEL)
	_shed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shed.position = Vector2(0.0, 0.0)
	_shed.size = rect.size - Vector2(16.0, 4.0)
	_shed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cash_out.add_child(_shed)
	_locked = PanelContainer.new()
	var outline: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 24)
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = Color(Palette.GOLD, 0.35)
	outline.content_margin_left = 14
	outline.content_margin_right = 10
	_locked.add_theme_stylebox_override("panel", outline)
	_locked.position = rect.position
	_locked.custom_minimum_size = rect.size
	_frame.add_child(_locked)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_locked.add_child(row)
	row.add_child(Icons.rect("icons/lock", 15.0, Palette.MUTED))
	_locked_note = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	_locked_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_locked_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_locked_note.add_theme_constant_override("line_spacing", -2)
	row.add_child(_locked_note)


func _refresh() -> void:
	var hud: FloorHudVM = _vm.hud()
	_clock.refresh(hud)
	_bankroll.refresh(hud)
	_heat.refresh(hud)
	_board.show_nodes(_vm.nodes(), _vm.row_count(), _vm.focus_row())
	_node.refresh(_vm)
	_cash_out.visible = _vm.can_cash_out()
	_shed.text = _vm.cash_out_text()
	_locked.visible = not _vm.can_cash_out()
	_locked_note.text = _vm.cash_out_note()


## For scripts/shot: picks a node, walks to the picked one.
func _pick(row: int, lane: int) -> void:
	_on_pick(row, lane)


func _on_pick(row: int, lane: int) -> void:
	_vm.select(row, lane)
	_refresh()


func _on_walk() -> void:
	_vm.walk()
	moved.emit()


func _on_cash_out() -> void:
	_vm.cash_out()
	moved.emit()


func _on_home() -> void:
	_vm.go_home()
	moved.emit()
