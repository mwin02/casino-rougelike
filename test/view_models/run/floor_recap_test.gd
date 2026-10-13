extends GdUnitTestSuite
## A run's floors as the run end lists them (block U4, spec §11), on Medium:
## quotas $140,000, $560,000, $2.2M, $8.9M, $35.8M; the marker's interest
## is 25%, and ejection comes at run heat 100.

var _config: TuneConfig = TuneConfig.load_default().for_difficulty(2)
var _state: RunState


func before_test() -> void:
	_state = RunState.new_run(_config)


func _add(
	outcome: FloorRecord.Outcome, quota: int, bankroll: int, loan: int = 0
) -> void:
	_state.records.append(
		FloorRecord.new(_state.records.size() + 1, outcome, quota, bankroll, loan)
	)


func _recaps() -> Array[FloorRecap]:
	return FloorRecap.of(_state, _config)


func test_every_floor_of_the_tower_is_listed() -> void:
	_add(FloorRecord.Outcome.MET, 140_000, 168_400)
	var recaps: Array[FloorRecap] = _recaps()
	assert_int(recaps.size()).is_equal(TuneSchema.FLOORS)
	assert_str(recaps[0].title).is_equal("Floor 1")
	assert_str(recaps[4].title).is_equal("Floor 5")


func test_a_met_floor_shows_its_check() -> void:
	_add(FloorRecord.Outcome.MET, 140_000, 168_400)
	var recap: FloorRecap = _recaps()[0]
	assert_str(recap.status).is_equal("MET")
	assert_int(recap.tone).is_equal(FloorRecap.Tone.GOOD)
	assert_str(recap.quota_text).is_equal("Quota $140,000")
	assert_str(recap.check_label).is_equal("AT THE CHECK")
	assert_str(recap.check_text).is_equal("$168,400")
	assert_str(recap.detail).is_equal("Floor 1: passed $28,400 over.")


func test_a_floor_not_reached_shows_its_quota_and_no_check() -> void:
	_add(FloorRecord.Outcome.MET, 140_000, 168_400)
	var recap: FloorRecap = _recaps()[1]
	assert_str(recap.status).is_equal("NOT REACHED")
	assert_int(recap.tone).is_equal(FloorRecap.Tone.NONE)
	assert_str(recap.quota_text).is_equal("Quota $560,000")
	assert_str(recap.check_label).is_equal("NO CHECK")
	assert_str(recap.check_text).is_equal("—")
	assert_str(recap.detail).is_equal("Floor 2: not reached.")


func test_a_floor_passed_on_the_marker_says_what_it_added() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 128_500, 11_500)
	var recap: FloorRecap = _recaps()[0]
	assert_str(recap.status).is_equal("MARKER")
	assert_int(recap.tone).is_equal(FloorRecap.Tone.MARKER)
	assert_str(recap.check_text).is_equal("$128,500")
	assert_str(recap.detail).is_equal(
		"Floor 1: short $11,500. The house fronted it; $14,375 added to floor 2's quota."
	)


func test_a_marker_called_mid_floor_reads_as_passed_on_the_loan() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 150_000, 70_000)
	assert_str(_recaps()[0].detail).is_equal(
		"Floor 1: passed $10,000 over on a $70,000 marker; $87,500 added to floor 2's quota."
	)


func test_the_floor_after_a_marker_says_its_quota_was_raised() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 128_500, 11_500)
	_add(FloorRecord.Outcome.MET, 574_375, 600_000)
	var recap: FloorRecap = _recaps()[1]
	assert_str(recap.quota_text).is_equal("Quota $574,375")
	assert_str(recap.detail).is_equal(
		"Floor 2: passed $25,625 over, quota raised by the floor 1 marker."
	)


func test_a_short_floor_says_why_no_marker_came() -> void:
	_add(FloorRecord.Outcome.MARKER, 140_000, 128_500, 11_500)
	_add(FloorRecord.Outcome.SHORT, 574_375, 500_000)
	var recap: FloorRecap = _recaps()[1]
	assert_str(recap.status).is_equal("SHORT")
	assert_int(recap.tone).is_equal(FloorRecap.Tone.BAD)
	assert_str(recap.detail).is_equal(
		"Floor 2: short $74,375 at the check. Marker already used."
	)


func test_a_shortfall_too_big_for_the_marker_says_so() -> void:
	_add(FloorRecord.Outcome.SHORT, 140_000, 20_000)
	assert_str(_recaps()[0].detail).is_equal(
		"Floor 1: short $120,000 at the check. More than the marker covers."
	)


func test_the_last_floor_has_no_marker() -> void:
	for i: int in TuneSchema.FLOORS - 1:
		_add(FloorRecord.Outcome.MET, 100, 200)
	_add(FloorRecord.Outcome.SHORT, 35_840_000, 35_000_000)
	assert_str(_recaps()[4].detail).is_equal(
		"Floor 5: short $840,000 at the check. The marker never covers the last floor."
	)


func test_an_ejection_shows_the_bankroll_when_it_came() -> void:
	_add(FloorRecord.Outcome.EJECTED, 140_000, 91_000)
	var recap: FloorRecap = _recaps()[0]
	assert_str(recap.status).is_equal("EJECTED")
	assert_int(recap.tone).is_equal(FloorRecap.Tone.BAD)
	assert_str(recap.check_label).is_equal("WHEN EJECTED")
	assert_str(recap.check_text).is_equal("$91,000")
	assert_str(recap.detail).is_equal(
		"Floor 1: run heat reached 100 when a session rolled over."
	)


func test_going_broke_shows_what_was_left() -> void:
	_add(FloorRecord.Outcome.BROKE, 140_000, 600)
	var recap: FloorRecap = _recaps()[0]
	assert_str(recap.status).is_equal("BROKE")
	assert_str(recap.check_label).is_equal("WHEN BROKE")
	assert_str(recap.check_text).is_equal("$600")
	assert_str(recap.detail).is_equal(
		"Floor 1: left a table under the $1,000 low-stakes minimum, with no marker to call."
	)
