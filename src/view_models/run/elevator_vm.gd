class_name ElevatorVM
extends RefCounted
## The elevator on screen (block U4, spec §5.3, §7.4): the bankroll carried
## in against the next floor's quota, the run heat a ride sheds, as the
## range it is rolled from, and a door for each floor on offer with its
## signature, quota, stakes and clock.

const TITLE: String = "Choose the next floor"
const HINT: String = "Two floors, two pressures. Pick the one your build can live with."
const ONE_DOOR: String = "One way up: the top floor."
const DOORS: Array[String] = ["LEFT DOOR", "RIGHT DOOR"]

var _owner: RunVM
var _run: Run
var _state: RunState
var _config: TuneConfig
var _heat: RunHeat


## owner's run is at the elevator.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_state = _run.state
	_config = _run.config()
	_heat = RunHeat.from_config(_config)


## For run heat's marks; its clock and quota are the floor just left.
func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


## "ELEVATOR · FLOOR 1 → FLOOR 2".
func heading() -> String:
	return "ELEVATOR · FLOOR %d → FLOOR %d" % [_state.floor_number - 1, _state.floor_number]


func hint() -> String:
	return HINT if _run.options.size() > 1 else ONE_DOOR


func bankroll_text() -> String:
	return MoneyFormat.format(_state.bankroll)


## "Floor 2 quota $560,000".
func quota_text() -> String:
	return "Floor %d quota %s" % [_state.floor_number, MoneyFormat.format(_quota())]


## "$391,600 to go".
func gap_text() -> String:
	return MoneyFormat.format(maxi(_quota() - _state.bankroll, 0)) + " to go"


## The bankroll as a share of the next quota, 0 to 1.
func quota_share() -> float:
	return clampf(float(_state.bankroll) / maxf(_quota(), 1.0), 0.0, 1.0)


func heat_text() -> String:
	return str(roundi(_state.run_heat))


## Run heat after the ride, as the range it can land in: "26–31".
func heat_after_text() -> String:
	var low: int = roundi(_after(_shed_max()))
	var high: int = roundi(_after(_shed_min()))
	return str(low) if low == high else "%d–%d" % [low, high]


## "Ride −15 to −20".
func shed_text() -> String:
	return "Ride −%d to −%d" % [roundi(_shed_min()), roundi(_shed_max())]


## Run heat now as a share of the ejection threshold, 0 to 1.
func heat_share() -> float:
	return clampf(_state.run_heat / _heat.eject_at, 0.0, 1.0)


## The least run heat the ride can leave, as that share.
func heat_after_share() -> float:
	return clampf(_after(_shed_max()) / _heat.eject_at, 0.0, 1.0)


func options() -> Array[ElevatorOption]:
	var doors: Array[ElevatorOption] = []
	for i: int in _run.options.size():
		doors.append(_option(i, _run.options[i]))
	return doors


## Rides to the floor behind the door at index.
func ride(index: int) -> void:
	if _run.ride(index):
		_owner.step_done()


func _option(index: int, signature: FloorSignature) -> ElevatorOption:
	var door: ElevatorOption = ElevatorOption.new()
	var floor_text: String = "FLOOR %d" % _state.floor_number
	door.door = floor_text
	if _run.options.size() > 1:
		door.door = "%s · %s" % [DOORS[index], floor_text]
	door.name = SignatureText.name_of(signature.kind)
	door.plain = SignatureText.plain(signature.kind)
	door.quota_text = MoneyFormat.format(_quota())
	if _state.quota_carry > 0:
		door.marker_text = "%s + %s marker (loan + %d%%)" % [
			MoneyFormat.format(_quota() - _state.quota_carry),
			MoneyFormat.format(_state.quota_carry),
			_config.get_int("marker", "interest_pct"),
		]
	door.stakes_text = "LOW %s · HIGH %s" % [_stakes("low"), _stakes("high")]
	var base: int = _config.get_int("clock", "hands_per_floor")
	var cut: int = base - signature.clock_hands(base)
	var extra: int = _state.extra_hands + _state.carried_hands + _run.kit.extra_floor_hands
	door.hands_text = "%d hands" % (base - cut + extra)
	door.short_clock = cut > 0
	if extra > 0:
		door.clock_note = "%d + %d extra" % [base - cut, extra]
	elif cut > 0:
		door.clock_note = "%d fewer" % cut
	door.ride_text = "Ride to " + door.name
	return door


## The next floor's quota, any marker debt included (§11).
func _quota() -> int:
	var quotas: Array[int] = _config.get_int_list("floors", "quotas")
	return quotas[_state.floor_number - 1] + _state.quota_carry


## "$4,000–$16,000" for the next floor's low or high tables.
func _stakes(tier: String) -> String:
	var at: int = _state.floor_number - 1
	return "%s–%s" % [
		MoneyFormat.format(_config.get_int_list("floors", tier + "_stakes_min")[at]),
		MoneyFormat.format(_config.get_int_list("floors", tier + "_stakes_max")[at]),
	]


func _shed_min() -> float:
	return _config.get_float("run_heat", "elevator_shed_min")


func _shed_max() -> float:
	return _config.get_float("run_heat", "elevator_shed_max")


## Run heat once shed is taken off, never below none.
func _after(shed: float) -> float:
	return maxf(_state.run_heat - shed, 0.0)
