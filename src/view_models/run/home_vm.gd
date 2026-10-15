class_name HomeVM
extends RefCounted
## The home screen (block U4): continue the saved run, start a new one at a
## chosen difficulty, or abandon the saved one. A new run waits until the
## saved one is abandoned, and abandoning takes a second press.

const CONTINUE: String = "Continue"
const ABANDON: String = "Abandon run"
const ABANDON_SURE: String = "Tap again to abandon"
const START_BLOCKED: String = "Abandon the saved run to start a new one."

var _owner: RunVM
## Where the saved run is, read once; empty with none.
var _saved: String
## Abandon has been pressed once.
var _armed: bool = false


func _init(owner: RunVM) -> void:
	_owner = owner
	_saved = owner.continue_text()


func can_continue() -> bool:
	return not _saved.is_empty()


## "Continue · Floor 2 · $154,400".
func continue_label() -> String:
	return "%s · %s" % [CONTINUE, _saved] if can_continue() else CONTINUE


func continue_run() -> void:
	_armed = false
	_owner.continue_run()


func difficulty_choices() -> Array[Choice]:
	return _owner.difficulty_choices()


func choose_difficulty(level: int) -> void:
	_armed = false
	_owner.choose_difficulty(level)


func can_start() -> bool:
	return not can_continue()


## Why a new run can't start; empty when it can.
func start_note() -> String:
	return "" if can_start() else START_BLOCKED


func start() -> void:
	if can_start():
		_owner.start()


func can_abandon() -> bool:
	return can_continue()


func abandon_label() -> String:
	return ABANDON_SURE if _armed else ABANDON


## The first press asks; the second gives the saved run up.
func press_abandon() -> void:
	if not can_abandon():
		return
	if not _armed:
		_armed = true
		return
	_armed = false
	_owner.abandon()
	_saved = ""
