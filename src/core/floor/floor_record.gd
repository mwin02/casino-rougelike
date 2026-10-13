class_name FloorRecord
extends RefCounted
## How one floor of a run ended, kept for the run summary (spec §11): its
## quota, and the bankroll at the quota check, or when the run was lost
## before one.

enum Outcome {
	## The bankroll reached the quota.
	MET,
	## Passed on the marker's money, fronted at the check or mid-floor.
	MARKER,
	## Short at the check with no marker to cover it.
	SHORT,
	## Run heat reached the ejection threshold (§7.4).
	EJECTED,
	## Broke mid-floor with no marker to call.
	BROKE,
}

var floor_number: int
var outcome: Outcome
## The floor's quota, last floor's marker debt included.
var quota: int
## Before any money the marker fronted at the check.
var bankroll: int
## Dollars the marker fronted on this floor.
var loan: int


func _init(
	p_floor_number: int, p_outcome: Outcome, p_quota: int, p_bankroll: int, p_loan: int = 0
) -> void:
	floor_number = p_floor_number
	outcome = p_outcome
	quota = p_quota
	bankroll = p_bankroll
	loan = p_loan


func to_dict() -> Dictionary:
	return {
		"floor_number": floor_number,
		"outcome": outcome,
		"quota": quota,
		"bankroll": bankroll,
		"loan": loan,
	}


static func from_dict(saved: Dictionary) -> FloorRecord:
	var p_floor_number: int = saved["floor_number"]
	var p_outcome: int = saved["outcome"]
	var p_quota: int = saved["quota"]
	var p_bankroll: int = saved["bankroll"]
	var p_loan: int = saved["loan"]
	return FloorRecord.new(p_floor_number, p_outcome as Outcome, p_quota, p_bankroll, p_loan)
