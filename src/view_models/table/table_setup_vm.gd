class_name TableSetupVM
extends RefCounted
## The debug table's setup: which game, stakes and floor to sit down at,
## under which house rule, and which kit to play with. The kit lasts across
## tables, as a run's would.

enum KitChoice { EVERYTHING, STARTING }

const GAME_NAMES: Array[String] = ["Blackjack", "Baccarat", "High or Low"]
const STAKES_NAMES: Array[String] = ["Low stakes", "High stakes"]
const KIT_NAMES: Array[String] = ["Every action", "Starting kit"]
const FLOORS: int = 5
## The debug kit's consumables, so keeping a change is always reachable.
const DEBUG_TAPE: int = 3
const DEBUG_SEALS: int = 3

var game: GameKind.Kind = GameKind.Kind.BLACKJACK
var stakes: TableStakes.Kind = TableStakes.Kind.LOW
var floor_number: int = 1
## The table's house rule by config name (§5.2); empty for none.
var house_rule: String = ""
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


## No rule, then every house rule that fits the chosen game.
func house_rule_choices() -> Array[Choice]:
	var result: Array[Choice] = [Choice.new(HouseRuleText.NO_RULE, true, 0, house_rule.is_empty())]
	var rules: Array[String] = _fitting_rules()
	for i: int in rules.size():
		result.append(
			Choice.new(HouseRuleText.name_of(rules[i]), true, i + 1, rules[i] == house_rule)
		)
	return result


func kit_choices() -> Array[Choice]:
	return _named(KIT_NAMES, kit_choice)


## A rule that doesn't fit the new game is dropped.
func choose_game(id: int) -> void:
	game = id as GameKind.Kind
	if house_rule not in _fitting_rules():
		house_rule = ""


func choose_house_rule(id: int) -> void:
	var rules: Array[String] = _fitting_rules()
	house_rule = rules[id - 1] if id >= 1 and id <= rules.size() else ""


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
	var chosen: Table = Table.from_config(_config, game, stakes, floor_number)
	chosen.house_rule = house_rule
	return chosen


func _fitting_rules() -> Array[String]:
	return _config.house_rules_for(GameKind.config_section(game))


## Every action: all unlock items, Loaded Question, the Pit Ledger,
## consumables, and a floor's Permanent Ink charges, past the slot count.
## The starting kit is the spec's (§2.4).
func _build_kit(choice: KitChoice) -> ActionKit:
	if choice == KitChoice.STARTING:
		return ActionKit.starting()
	var built: ActionKit = ActionKit.everything()
	var rules: ItemRules = ItemRules.from_config(_config)
	rules.slots = ItemKind.Kind.size()
	built.add_item(ItemKind.Kind.LOADED_QUESTION, rules)
	built.add_item(ItemKind.Kind.PIT_LEDGER, rules)
	built.masking_tape = DEBUG_TAPE
	built.cold_seals = DEBUG_SEALS
	built.ink_charges = _config.get_int("items", "ink_charges_per_floor")
	return built


static func _named(names: Array[String], chosen: int) -> Array[Choice]:
	var result: Array[Choice] = []
	for i: int in names.size():
		result.append(Choice.new(names[i], true, i, i == chosen))
	return result
