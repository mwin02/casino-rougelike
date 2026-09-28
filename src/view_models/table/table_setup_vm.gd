class_name TableSetupVM
extends RefCounted
## The debug table's setup: which game, stakes and floor to sit down at, and
## which kit to play with. The kit lasts across tables, as a run's would.

enum KitChoice { EVERYTHING, STARTING }

const GAME_NAMES: Array[String] = ["Blackjack", "Baccarat", "High or Low"]
const STAKES_NAMES: Array[String] = ["Low stakes", "High stakes"]
const KIT_NAMES: Array[String] = ["Every action", "Starting kit"]
const FLOORS: int = 5
## The debug kit's consumables, so keeping a change is always reachable.
const DEBUG_TAPE: int = 3
const DEBUG_SEALS: int = 3
## §9 Loaded Question: the debug kit's partial reveals answer two questions.
const LOADED_QUESTIONS: int = 2

var game: GameKind.Kind = GameKind.Kind.BLACKJACK
var stakes: TableStakes.Kind = TableStakes.Kind.LOW
var floor_number: int = 1
var kit_choice: KitChoice = KitChoice.EVERYTHING
var kit: ActionKit

var _config: TuneConfig


func _init(config: TuneConfig) -> void:
	_config = config
	kit = _build_kit(kit_choice)


func game_choices() -> Array[Choice]:
	return _named(GAME_NAMES, game)


func stakes_choices() -> Array[Choice]:
	return _named(STAKES_NAMES, stakes)


func floor_choices() -> Array[Choice]:
	var result: Array[Choice] = []
	for number: int in range(1, FLOORS + 1):
		result.append(Choice.new("Floor %d" % number, true, number, number == floor_number))
	return result


func kit_choices() -> Array[Choice]:
	return _named(KIT_NAMES, kit_choice)


func choose_game(id: int) -> void:
	game = id as GameKind.Kind


func choose_stakes(id: int) -> void:
	stakes = id as TableStakes.Kind


func choose_floor(id: int) -> void:
	floor_number = clampi(id, 1, FLOORS)


## Swaps the kit for a fresh one: consumables and Ink charges refill.
func choose_kit(id: int) -> void:
	kit_choice = id as KitChoice
	kit = _build_kit(kit_choice)


## The chosen table, its bet range from the floor's stakes (spec §6.3).
func table() -> Table:
	return Table.from_config(_config, game, stakes, floor_number)


## Every action: all unlocks, Loaded Question, consumables, and a floor's
## Permanent Ink charges. The starting kit is the spec's (§2.4).
func _build_kit(choice: KitChoice) -> ActionKit:
	if choice == KitChoice.STARTING:
		return ActionKit.starting()
	var built: ActionKit = ActionKit.everything()
	built.questions_per_reveal = LOADED_QUESTIONS
	built.masking_tape = DEBUG_TAPE
	built.cold_seals = DEBUG_SEALS
	built.ink_charges = _config.get_int("items", "ink_charges_per_floor")
	return built


static func _named(names: Array[String], chosen: int) -> Array[Choice]:
	var result: Array[Choice] = []
	for i: int in names.size():
		result.append(Choice.new(names[i], true, i, i == chosen))
	return result
