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
	_refresh()


func _refresh() -> void:
	var hud: FloorHudVM = _vm.hud()
	_clock.refresh(hud)
	_bankroll.refresh(hud)
	_heat.refresh(hud)


func _on_home() -> void:
	_vm.go_home()
	moved.emit()
