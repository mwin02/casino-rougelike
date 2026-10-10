class_name Run
extends RefCounted
## A whole run, the tower of five floors (spec §5.3, §7.4, §11). Floor 1
## plays at the baseline. Once a floor is done, a passed one opens the
## elevator: two signatures from the pool for floors 2–4, only the boss
## floor for floor 5. Riding it sheds run heat and starts the chosen floor.
## Floor 5's quota wins the run; a lost floor, ejection included, loses it.
##
## A run plays at one difficulty level (§6.3), which sets its quotas, stakes
## and prices; the run keeps its config at that level, and resumes at it.
##
## The player plays each floor through it; end_floor() moves the run on once
## the floor is DONE. The whole run saves (SaveStore) at any point but
## mid-hand.

enum Phase {
	## Playing the current floor.
	FLOOR,
	## Choosing the next floor.
	ELEVATOR,
	WON,
	LOST,
}

## Save format version; bump when the saved shape changes.
const VERSION: int = 7
## Run.start: play at the config's own level.
const CONFIG_LEVEL: int = -1

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


## kit null is the starting kit (§2.4); the harness passes its own. Null if
## config doesn't list the difficulty level.
static func start(
	config: TuneConfig, run_seed: int, p_kit: ActionKit = null, difficulty: int = CONFIG_LEVEL
) -> Run:
	var level: int = config.difficulty() if difficulty == CONFIG_LEVEL else difficulty
	var at_level: TuneConfig = config.for_difficulty(level)
	if at_level == null:
		return null
	config = at_level
	var run: Run = Run.new()
	run._config = config
	run.game = GameState.new_run(run_seed, DeckRules.from_config(config).min_size)
	run.kit = p_kit if p_kit != null else ActionKit.starting()
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


## False only mid-hand.
func can_save() -> bool:
	return floor.session == null or not floor.session.in_hand()


func to_dict() -> Dictionary:
	var saved_options: Array[int] = []
	for option: FloorSignature in options:
		saved_options.append(option.kind)
	return {
		"version": VERSION,
		"game": game.to_dict(),
		"kit": kit.to_dict(),
		"state": state.to_dict(),
		"phase": phase,
		"options": saved_options,
		"last_shed": last_shed,
		"floor": floor.to_dict(),
	}


## Builds from well-formed data, at the saved difficulty level. Loading
## from disk goes through SaveStore.from_saved, which checks the version,
## shape and level first.
static func from_dict(saved: Dictionary, base_config: TuneConfig) -> Run:
	var saved_game: Dictionary = saved["game"]
	var saved_kit: Dictionary = saved["kit"]
	var saved_state: Dictionary = saved["state"]
	var saved_floor: Dictionary = saved["floor"]
	var level: int = saved_state["difficulty"]
	var config: TuneConfig = base_config.for_difficulty(level)
	var run: Run = Run.new()
	run._config = config
	run.game = GameState.from_dict(saved_game, DeckRules.from_config(config).min_size)
	run.kit = ActionKit.from_dict(saved_kit, ItemRules.from_config(config))
	run.state = RunState.from_dict(saved_state)
	var saved_phase: int = saved["phase"]
	run.phase = saved_phase as Phase
	var saved_options: Array = saved["options"]
	for kind: int in saved_options:
		run.options.append(FloorSignature.of(config, kind as FloorSignature.Kind))
	run.last_shed = saved["last_shed"]
	run.floor = Floor.from_dict(
		saved_floor, config, run.state, run.game.deck, run.game.layer, run.kit, run.game.rng
	)
	return run


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
