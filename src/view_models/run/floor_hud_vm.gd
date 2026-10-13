class_name FloorHudVM
extends RefCounted
## What every floor screen shows of the run (block U4): which floor this is,
## the hand clock (spec §6.1), the bankroll against the quota (§6.2), and
## run heat against its thresholds (§7.4).

const REACHED: String = "Quota reached"

var _run: Run
var _floor: Floor
var _heat: RunHeat


func _init(run: Run) -> void:
	_run = run
	_floor = run.floor
	_heat = RunHeat.from_config(run.config())


## "FLOOR 2 · WATCHFUL PIT".
func floor_title() -> String:
	var signature: String = SignatureText.name_of(_floor.signature.kind)
	return ("Floor %d · %s" % [_run.state.floor_number, signature]).to_upper()


## "27 hands left".
func hands_left_text() -> String:
	var hands: int = _floor.clock.hands_left
	return "%d %s left" % [hands, "hand" if hands == 1 else "hands"]


## "of 60".
func hands_total_text() -> String:
	return "of %d" % _floor.clock.total


## Hands left as a share of the floor's pool, 0 to 1.
func hands_share() -> float:
	return clampf(float(_floor.clock.hands_left) / maxf(_floor.clock.total, 1.0), 0.0, 1.0)


func bankroll_text() -> String:
	return MoneyFormat.format(_run.state.bankroll)


## "Quota $140,000".
func quota_text() -> String:
	return "Quota " + MoneyFormat.format(_floor.quota)


func at_quota() -> bool:
	return _run.state.bankroll >= _floor.quota


## "$35,200 to go", or "Quota reached".
func gap_text() -> String:
	if at_quota():
		return REACHED
	return MoneyFormat.format(_floor.quota - _run.state.bankroll) + " to go"


## The bankroll as a share of the quota, 0 to 1.
func quota_share() -> float:
	return clampf(float(_run.state.bankroll) / maxf(_floor.quota, 1.0), 0.0, 1.0)


## Whole, as every heat number on screen is (§1.4).
func run_heat_text() -> String:
	return str(roundi(_run.state.run_heat))


## Run heat as a share of the ejection threshold, 0 to 1.
func run_heat_share() -> float:
	return clampf(_run.state.run_heat / _heat.eject_at, 0.0, 1.0)


## The pit boss, sweep and ejection thresholds, as numbers to print.
func heat_marks() -> Array[int]:
	return [roundi(_heat.pit_boss_at), roundi(_heat.sweep_at), roundi(_heat.eject_at)]


## Where each mark sits on the meter, 0 to 1.
func heat_mark_shares() -> Array[float]:
	return [_heat.pit_boss_at / _heat.eject_at, _heat.sweep_at / _heat.eject_at, 1.0]


## Whether run heat has reached each mark.
func heat_marks_reached() -> Array[bool]:
	var heat: float = _run.state.run_heat
	return [heat >= _heat.pit_boss_at, heat >= _heat.sweep_at, heat >= _heat.eject_at]


## True once the pit boss is on the floor (§7.5).
func pit_boss() -> bool:
	return _run.state.run_heat >= _heat.pit_boss_at
