extends GdUnitTestSuite
## The run's event log: ordered, filterable, read by cursor (block 1).

var _log: EventLog


func before_test() -> void:
	_log = EventLog.new()


func _seqs(events: Array[GameEvent]) -> Array[int]:
	var seqs: Array[int] = []
	for event: GameEvent in events:
		seqs.append(event.seq)
	return seqs


func test_events_get_increasing_seq_numbers() -> void:
	var first: GameEvent = _log.append(&"a")
	var second: GameEvent = _log.append(&"b", {"x": 1})
	assert_int(second.seq).is_greater(first.seq)
	assert_int(_log.last_seq()).is_equal(second.seq)
	assert_int(_log.size()).is_equal(2)


func test_empty_log_has_no_last_seq() -> void:
	assert_int(_log.last_seq()).is_equal(EventLog.NO_SEQ)
	assert_array(_log.since(EventLog.NO_SEQ)).is_empty()


func test_since_returns_only_newer_events() -> void:
	_log.append(&"a")
	var cursor: int = _log.append(&"b").seq
	var third: GameEvent = _log.append(&"c")
	var fourth: GameEvent = _log.append(&"d")
	assert_array(_seqs(_log.since(cursor))).is_equal([third.seq, fourth.seq])
	assert_int(_log.since(EventLog.NO_SEQ).size()).is_equal(4)


func test_of_kind_filters_in_order() -> void:
	var a1: GameEvent = _log.append(&"a")
	_log.append(&"b")
	var a2: GameEvent = _log.append(&"a")
	assert_array(_seqs(_log.of_kind(&"a"))).is_equal([a1.seq, a2.seq])


func test_data_is_copied_on_append() -> void:
	var data: Dictionary = {"heat": 3}
	var event: GameEvent = _log.append(&"a", data)
	data["heat"] = 99
	assert_int(event.data["heat"]).is_equal(3)
