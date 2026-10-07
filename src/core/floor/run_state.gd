class_name RunState
extends RefCounted
## What carries from floor to floor in a run: the bankroll, run heat
## (spec §7.4), extra hands for the next floor's clock (§6.4), and the
## marker (§11). Block 14 builds the tower on it.

## 1–5.
var floor_number: int = 1
var bankroll: int
var run_heat: float = 0.0
## Extra hands bought on the floor before, added to this floor's clock.
var extra_hands: int = 0
## §11: the marker is spent once the house has fronted money.
var marker_used: bool = false
## Marker loan plus interest added to this floor's quota.
var quota_carry: int = 0
var lost: bool = false
var won: bool = false


static func new_run(config: TuneConfig) -> RunState:
	var run: RunState = RunState.new()
	run.bankroll = config.get_int("floors", "start_bankroll")
	return run


func add_run_heat(amount: float) -> void:
	run_heat += amount


## Sheds up to amount, never below 0. Returns what was shed.
func shed_run_heat(amount: float) -> float:
	var shed: float = minf(amount, run_heat)
	run_heat -= shed
	return shed
