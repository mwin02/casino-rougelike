class_name RunVM
extends RefCounted
## The run on screen (block U4): the home screen's choices, the Run being
## played, which screen it is at, and its save. The screens' own view models
## change the run and call step_done(); the table calls hand_settled().
##
## The run saves after every settled hand, after every step between hands
## and when the app goes to the background. A save is never written
## mid-hand (Run.can_save), so an app killed there comes back before that
## hand. A run that ends, or is abandoned, leaves no save.

enum Screen {
	HOME,
	MAP,
	## At a node of tables, not yet seated.
	OFFERS,
	TABLE,
	SHOP,
	DECK_SERVICES,
	SWEEP,
	END_SHOP,
	ELEVATOR,
	RUN_END,
}

const LEVEL_NAMES: Dictionary[int, String] = { 0: "Easy", 2: "Medium", 4: "Hard" }

## The run in play, or the one that just ended; null at the home screen.
var run: Run
## The level a new run starts at (spec §6.3).
var difficulty: int

## Looking at the map from a node's table offers, with nothing decided.
var _viewing_map: bool = false

var _config: TuneConfig
## Where each new run's seed comes from.
var _seeds: RandomNumberGenerator
var _path: String


func _init(
	config: TuneConfig, seeds: RandomNumberGenerator, path: String = SaveStore.DEFAULT_PATH
) -> void:
	_config = config
	_seeds = seeds
	_path = path
	difficulty = config.difficulty()


func screen() -> Screen:
	if run == null:
		return Screen.HOME
	if run.phase == Run.Phase.ELEVATOR:
		return Screen.ELEVATOR
	if run.phase != Run.Phase.FLOOR:
		return Screen.RUN_END
	return _floor_screen(run.floor)


func _floor_screen(floor: Floor) -> Screen:
	match floor.phase:
		Floor.Phase.AT_TABLE:
			if floor.session != null:
				return Screen.TABLE
			return Screen.MAP if _viewing_map else Screen.OFFERS
		Floor.Phase.AT_STOP:
			return Screen.SHOP if floor.shop != null else Screen.DECK_SERVICES
		Floor.Phase.SWEEP:
			return Screen.SWEEP
		Floor.Phase.END_SHOP:
			return Screen.END_SHOP
	return Screen.MAP


## True at a node of tables with no seat taken yet.
func at_offers() -> bool:
	if run == null or run.phase != Run.Phase.FLOOR:
		return false
	return run.floor.phase == Floor.Phase.AT_TABLE and run.floor.session == null


## Shows the map from a node's table offers, or the offers again. Nothing
## about the node is decided either way.
func view_map(shown: bool) -> void:
	_viewing_map = shown and at_offers()


## One per configured level, the chosen one selected.
func difficulty_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	for level: int in _config.levels():
		var label: String = LEVEL_NAMES.get(level, "Level %d" % level)
		result.append(Choice.new(label, true, level, level == difficulty))
	return result


func choose_difficulty(level: int) -> void:
	if _config.has_difficulty(level):
		difficulty = level


## Starts a new run at the chosen difficulty, over any saved one.
func start() -> void:
	var run_seed: int = _seeds.randi()
	print("run: seed ", run_seed)
	run = Run.start(_config, run_seed, null, difficulty)
	save()


## True when a run on disk can be continued.
func has_save() -> bool:
	return SaveStore.load_from(_config, _path) != null


## Where the saved run is: "Floor 2 · $154,400". Empty with none.
func continue_text() -> String:
	var saved: Run = SaveStore.load_from(_config, _path)
	if saved == null:
		return ""
	var state: RunState = saved.state
	return "Floor %d · %s" % [state.floor_number, MoneyFormat.format(state.bankroll)]


## Resumes the saved run where it was saved. False with none to resume.
## A run saved at a table whose session had ended leaves it now, which can
## end the run, so the save is written again or cleared.
func continue_run() -> bool:
	var saved: Run = SaveStore.load_from(_config, _path)
	if saved == null:
		return false
	run = saved
	_advance()
	save()
	return true


## Back to the home screen, the run saved to continue later.
func go_home() -> void:
	save()
	run = null
	_viewing_map = false


## Gives the saved run up.
func abandon() -> void:
	SaveStore.clear(_path)
	run = null


## A hand has just settled at the table.
func hand_settled() -> void:
	save()


## A screen has changed the run between hands: moves it on past the steps
## no screen stops at, then saves it, or clears the save if it ended.
func step_done() -> void:
	_viewing_map = false
	_advance()
	save()


func on_background() -> void:
	save()


## Writes the run in play; clears the save once the run is over. Leaves the
## last save alone mid-hand.
func save() -> void:
	if run == null:
		return
	if run.phase in [Run.Phase.WON, Run.Phase.LOST]:
		SaveStore.clear(_path)
		return
	var err: Error = SaveStore.save(run, _path)
	if err != OK and err != ERR_BUSY:
		push_warning("RunVM: save failed (%s)" % error_string(err))


## A table whose session has ended is left, when a run is resumed there.
## The quota check and the end of a floor have no screen of their own: the
## end shop shows the check's result, the run end a lost one.
func _advance() -> void:
	if run.phase != Run.Phase.FLOOR:
		return
	var session: TableSession = run.floor.session
	if session != null and session.ended() != null:
		run.floor.leave()
	if run.floor.phase == Floor.Phase.QUOTA_CHECK:
		run.floor.check_quota()
	if run.floor.phase == Floor.Phase.DONE:
		run.end_floor()
