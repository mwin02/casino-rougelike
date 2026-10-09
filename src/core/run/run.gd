class_name Run
extends RefCounted
## A whole run, the tower of five floors (spec §5.3, §7.4, §11). Floor 1
## plays at the baseline. Once a floor is done, a passed one opens the
## elevator: two signatures from the pool for floors 2–4, only the boss
## floor for floor 5. Riding it sheds run heat and starts the chosen floor.
## Floor 5's quota wins the run; a lost floor, ejection included, loses it.
##
## The player plays each floor through it; end_floor() moves the run on once
## the floor is DONE.

enum Phase {
	## Playing the current floor.
	FLOOR,
	## Choosing the next floor.
	ELEVATOR,
	WON,
	LOST,
}

var phase: Phase = Phase.FLOOR
## The deck, layer, RNG and event log.
var game: GameState
var kit: ActionKit
## What carries from floor to floor.
var state: RunState
var floor: Floor
## The elevator's floor options. Empty away from the elevator.
var options: Array[FloorSignature] = []
## Run heat the last elevator ride shed.
var last_shed: float = 0.0

var _config: TuneConfig


static func start(config: TuneConfig, run_seed: int) -> Run:
	var run: Run = Run.new()
	run._config = config
	run.game = GameState.new_run(run_seed, DeckRules.from_config(config).min_size)
	run.kit = ActionKit.starting()
	run.state = RunState.new_run(config)
	run._start_floor(FloorSignature.baseline())
	return run


## Once the floor is done: the run is won or lost, or the elevator opens.
## Refused while the floor is still in play.
func end_floor() -> bool:
	if phase != Phase.FLOOR or floor.phase != Floor.Phase.DONE:
		return false
	if state.won:
		phase = Phase.WON
	elif state.lost:
		phase = Phase.LOST
	else:
		phase = Phase.ELEVATOR
		options = _roll_options()
	return true


## Rides the elevator to the option at index: sheds run heat and starts that
## floor.
func ride(index: int) -> bool:
	if phase != Phase.ELEVATOR or index < 0 or index >= options.size():
		return false
	var low: float = _config.get_float("run_heat", "elevator_shed_min")
	var high: float = _config.get_float("run_heat", "elevator_shed_max")
	var roll: float = game.rng.stream(GameRng.Stream.FLOOR).randf_range(low, high)
	last_shed = state.shed_run_heat(roll)
	var chosen: FloorSignature = options[index]
	options = []
	_start_floor(chosen)
	phase = Phase.FLOOR
	return true


func score() -> RunScore:
	return RunScore.of(state)


func _start_floor(signature: FloorSignature) -> void:
	floor = Floor.new(
		_config, state, game.deck, game.layer, kit, game.rng, null, signature
	)


## Two signatures from the pool, never the same twice; the boss floor alone
## for the last floor.
func _roll_options() -> Array[FloorSignature]:
	var result: Array[FloorSignature] = []
	if state.floor_number == TuneSchema.FLOORS:
		result.append(FloorSignature.of(_config, FloorSignature.Kind.BOSS))
		return result
	var pool: Array[FloorSignature.Kind] = FloorSignature.POOL.duplicate()
	var rng: RandomNumberGenerator = game.rng.stream(GameRng.Stream.FLOOR)
	for i: int in mini(2, pool.size()):
		var kind: FloorSignature.Kind = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(kind)
		result.append(FloorSignature.of(_config, kind))
	return result
