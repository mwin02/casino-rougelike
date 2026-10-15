class_name FloorRecap
extends RefCounted
## One floor of the tower as the run end lists it (block U4, spec §11): how
## it ended, its quota, the bankroll at its check, and the story in a line.
## Floors the run never reached are listed too.

## What a floor's outcome reads as, for its colour.
enum Tone { GOOD, MARKER, BAD, NONE }

const STATUS: Dictionary[FloorRecord.Outcome, String] = {
	FloorRecord.Outcome.MET: "MET",
	FloorRecord.Outcome.MARKER: "MARKER",
	FloorRecord.Outcome.SHORT: "SHORT",
	FloorRecord.Outcome.EJECTED: "EJECTED",
	FloorRecord.Outcome.BROKE: "BROKE",
}
const TONES: Dictionary[FloorRecord.Outcome, Tone] = {
	FloorRecord.Outcome.MET: Tone.GOOD,
	FloorRecord.Outcome.MARKER: Tone.MARKER,
	FloorRecord.Outcome.SHORT: Tone.BAD,
	FloorRecord.Outcome.EJECTED: Tone.BAD,
	FloorRecord.Outcome.BROKE: Tone.BAD,
}
const CHECK_LABELS: Dictionary[FloorRecord.Outcome, String] = {
	FloorRecord.Outcome.EJECTED: "WHEN EJECTED",
	FloorRecord.Outcome.BROKE: "WHEN BROKE",
}
const NOT_REACHED: String = "NOT REACHED"

## "Floor 3".
var title: String
## "MET", "MARKER", "SHORT", "EJECTED", "BROKE" or "NOT REACHED".
var status: String = NOT_REACHED
var tone: Tone = Tone.NONE
## "Quota $140,000", marker debt included for a floor that was played.
var quota_text: String
## "AT THE CHECK", "WHEN EJECTED", "WHEN BROKE" or "NO CHECK".
var check_label: String = "NO CHECK"
## The bankroll then; "—" for a floor not reached.
var check_text: String = "—"
## The floor's story in a line.
var detail: String


## Every floor of the tower, played or not, in order.
static func of(state: RunState, config: TuneConfig) -> Array[FloorRecap]:
	var recaps: Array[FloorRecap] = []
	var quotas: Array[int] = config.get_int_list("floors", "quotas")
	for i: int in TuneSchema.FLOORS:
		var recap: FloorRecap = FloorRecap.new()
		recap.title = "Floor %d" % (i + 1)
		recap.quota_text = "Quota " + MoneyFormat.format(quotas[i])
		recap.detail = "%s: not reached." % recap.title
		if i < state.records.size():
			recap._fill(state.records[i], state.records.slice(0, i), config)
		recaps.append(recap)
	return recaps


func _fill(record: FloorRecord, before: Array[FloorRecord], config: TuneConfig) -> void:
	status = STATUS[record.outcome]
	tone = TONES[record.outcome]
	quota_text = "Quota " + MoneyFormat.format(record.quota)
	check_label = CHECK_LABELS.get(record.outcome, "AT THE CHECK")
	check_text = MoneyFormat.format(record.bankroll)
	detail = "%s: %s" % [title, _story(record, before, config)]


func _story(record: FloorRecord, before: Array[FloorRecord], config: TuneConfig) -> String:
	var gap: String = MoneyFormat.format(absi(record.bankroll - record.quota))
	match record.outcome:
		FloorRecord.Outcome.MET:
			var marker_floor: int = _marker_floor(before)
			if marker_floor > 0 and marker_floor == record.floor_number - 1:
				return "passed %s over, quota raised by the floor %d marker." % [gap, marker_floor]
			return "passed %s over." % gap
		FloorRecord.Outcome.MARKER:
			return _marker_story(record, gap, config)
		FloorRecord.Outcome.SHORT:
			return "short %s at the check. %s" % [gap, _no_marker(record, before)]
		FloorRecord.Outcome.EJECTED:
			var eject_at: int = roundi(RunHeat.from_config(config).eject_at)
			return "run heat reached %d when a session rolled over." % eject_at
	var low_min: int = config.get_int_list("floors", "low_stakes_min")[record.floor_number - 1]
	return (
		"left a table under the %s low-stakes minimum, with no marker to call."
		% MoneyFormat.format(low_min)
	)


## A floor passed on the marker: fronted at the check, or mid-floor.
func _marker_story(record: FloorRecord, gap: String, config: TuneConfig) -> String:
	var added: String = "%s added to floor %d's quota." % [
		MoneyFormat.format(Marker.owed(config, record.loan)), record.floor_number + 1,
	]
	if record.bankroll < record.quota:
		return "short %s. The house fronted it; %s" % [gap, added]
	return "passed %s over on a %s marker; %s" % [gap, MoneyFormat.format(record.loan), added]


## Why the house fronted nothing for a short check (§11).
func _no_marker(record: FloorRecord, before: Array[FloorRecord]) -> String:
	if _marker_floor(before) > 0:
		return "Marker already used."
	if record.floor_number == TuneSchema.FLOORS:
		return "The marker never covers the last floor."
	return "More than the marker covers."


## The floor the marker went on, among these; 0 for none.
func _marker_floor(records: Array[FloorRecord]) -> int:
	for record: FloorRecord in records:
		if record.loan > 0:
			return record.floor_number
	return 0
