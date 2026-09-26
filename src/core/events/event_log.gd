class_name EventLog
extends RefCounted
## Everything that happened in the run, in order. Readers keep a cursor (the
## last seq they saw) and pull what's new with since(); nothing is pushed.

const NO_SEQ: int = -1

var _events: Array[GameEvent] = []
var _next_seq: int = 0


## Records an event. data is deep-copied, so later changes to it don't leak in.
func append(kind: StringName, data: Dictionary = {}) -> GameEvent:
	var event: GameEvent = GameEvent.new(_next_seq, kind, data.duplicate(true))
	_next_seq += 1
	_events.append(event)
	return event


func size() -> int:
	return _events.size()


## The newest event's seq, or NO_SEQ if the log is empty.
func last_seq() -> int:
	return _events[-1].seq if not _events.is_empty() else NO_SEQ


## Events after seq, oldest first. since(NO_SEQ) is every event.
func since(seq: int) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event: GameEvent in _events:
		if event.seq > seq:
			result.append(event)
	return result


func of_kind(kind: StringName) -> Array[GameEvent]:
	var result: Array[GameEvent] = []
	for event: GameEvent in _events:
		if event.kind == kind:
			result.append(event)
	return result


func to_dict() -> Dictionary:
	var saved_events: Array[Dictionary] = []
	for event: GameEvent in _events:
		saved_events.append(event.to_dict())
	return {"next_seq": _next_seq, "events": saved_events}


static func from_dict(saved: Dictionary) -> EventLog:
	var restored: EventLog = EventLog.new()
	restored._next_seq = saved["next_seq"]
	var saved_events: Array = saved["events"]
	for saved_event: Dictionary in saved_events:
		restored._events.append(GameEvent.from_dict(saved_event))
	return restored
