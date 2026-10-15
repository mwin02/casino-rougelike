class_name RunEndVM
extends RefCounted
## The run end on screen (block U4, spec §11): how the run ended and its
## score, the run heat peak against its marks, the items held at the end,
## and the tower floor by floor, one floor explained at a time. From here a
## new run starts, or the home screen opens.

const PEAK_NOTES: Array[String] = ["Quiet", "Pit boss", "Sweep", "Ejected"]
const MARK_NAMES: Array[String] = ["PIT BOSS", "SWEEP", "OUT"]
const NEW_RUN: String = "New run"
const HOME: String = "Home"

var _owner: RunVM
var _run: Run
var _state: RunState
var _config: TuneConfig
var _heat: RunHeat
var _floors: Array[FloorRecap]
var _selected: int


## owner's run is won or lost.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_state = _run.state
	_config = _run.config()
	_heat = RunHeat.from_config(_config)
	_floors = FloorRecap.of(_state, _config)
	_selected = clampi(_state.records.size() - 1, 0, _floors.size() - 1)


func won() -> bool:
	return _state.won


func hero() -> RunEndHero:
	var hero: RunEndHero = RunEndHero.new()
	var score: RunScore = _run.score()
	var floor_number: int = maxi(_state.records.size(), 1)
	var start: String = "Started with %s." % MoneyFormat.format(_state.start_bankroll)
	hero.score_text = MoneyFormat.format(score.bankroll)
	if _state.won:
		hero.kicker = "RUN COMPLETE · FLOOR %d CLEARED" % floor_number
		hero.title = "You beat the house."
		hero.sub = "Floor %d's quota reached with %s to spare." % [
			floor_number, MoneyFormat.format(score.bankroll - _state.records[-1].quota),
		]
		hero.score_label = "FINAL SCORE"
		hero.per_heat_text = "%s per heat" % MoneyFormat.format(roundi(score.dollars_per_heat))
		hero.footnote = start + " Every floor met."
		return hero
	hero.kicker = "RUN OVER · FLOOR %d" % floor_number
	hero.score_label = "BANKROLL AT THE END"
	hero.footnote = "%s Reached floor %d of %d." % [start, floor_number, TuneSchema.FLOORS]
	_fill_loss(hero, floor_number)
	return hero


func peak_text() -> String:
	return str(roundi(_state.run_heat_peak))


## The highest mark the peak reached: "Quiet", "Pit boss", "Sweep" or
## "Ejected".
func peak_note() -> String:
	return PEAK_NOTES[peak_level()]


## How many of the three marks the peak reached, 0 to 3.
func peak_level() -> int:
	var level: int = 0
	for mark: float in [_heat.pit_boss_at, _heat.sweep_at, _heat.eject_at]:
		if _state.run_heat_peak >= mark:
			level += 1
	return level


## The peak as a share of the ejection threshold, 0 to 1.
func peak_share() -> float:
	return clampf(_state.run_heat_peak / _heat.eject_at, 0.0, 1.0)


## "40 PIT BOSS", "70 SWEEP", "100 OUT".
func mark_labels() -> Array[String]:
	var labels: Array[String] = []
	var marks: Array[float] = [_heat.pit_boss_at, _heat.sweep_at, _heat.eject_at]
	for i: int in marks.size():
		labels.append("%d %s" % [roundi(marks[i]), MARK_NAMES[i]])
	return labels


## Where each mark sits on the bar, 0 to 1.
func mark_shares() -> Array[float]:
	return [_heat.pit_boss_at / _heat.eject_at, _heat.sweep_at / _heat.eject_at, 1.0]


func slots() -> Array[ItemSlot]:
	return ItemSlot.of(_run.kit, _config)


## "4 of 6".
func item_count_text() -> String:
	return "%d of %d" % [_run.kit.items.size(), ItemRules.from_config(_config).slots]


func floors() -> Array[FloorRecap]:
	return _floors


## The floor whose story detail() tells.
func selected() -> int:
	return _selected


func select(index: int) -> void:
	if index >= 0 and index < _floors.size():
		_selected = index


func detail() -> String:
	return _floors[_selected].detail


## Starts a new run at this run's difficulty.
func new_run() -> void:
	_owner.choose_difficulty(_state.difficulty)
	_owner.start()


func home() -> void:
	_owner.go_home()


## A lost run's title and what went wrong.
func _fill_loss(hero: RunEndHero, floor_number: int) -> void:
	if _state.ejected:
		hero.title = "Ejected."
		hero.sub = "Run heat reached %d on floor %d. Security walked you out." % [
			roundi(_heat.eject_at), floor_number,
		]
		return
	var short: bool = (
		not _state.records.is_empty()
		and _state.records[-1].outcome == FloorRecord.Outcome.SHORT
	)
	hero.title = "%s on floor %d." % ["Short" if short else "Broke", floor_number]
	if short:
		hero.score_label = "BANKROLL AT THE CHECK"
	hero.sub = "The marker couldn't cover it."
	for record: FloorRecord in _state.records:
		if record.loan > 0:
			hero.sub = "A second failure. The marker went on floor %d." % record.floor_number
