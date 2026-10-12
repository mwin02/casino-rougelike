class_name HoldRepeat
extends Node
## Repeats a button's action while it's held: once at the press, then after
## a pause, faster and faster until the finger lifts. A panel keeps one and
## starts it from a button's button_down, so the hold outlives a button the
## panel rebuilds on each step.

const PAUSE: float = 0.4
const SLOWEST: float = 0.14
const FASTEST: float = 0.035
const SPEED_UP: float = 0.85

var _action: Callable
var _wait: float = 0.0
var _gap: float = SLOWEST


func _init() -> void:
	set_process(false)


func begin(action: Callable) -> void:
	_action = action
	_wait = PAUSE
	_gap = SLOWEST
	set_process(true)
	action.call()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_gap = maxf(_gap * SPEED_UP, FASTEST)
	_wait = _gap
	_action.call()


## The lift ends the hold wherever it lands, on the button or off it.
func _input(event: InputEvent) -> void:
	var lifted: bool = event is InputEventMouseButton or event is InputEventScreenTouch
	if lifted and not event.is_pressed():
		set_process(false)
