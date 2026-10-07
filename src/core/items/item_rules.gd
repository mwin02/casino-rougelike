class_name ItemRules
extends RefCounted
## Item [TUNE] values (spec §9): the slot count and each item's numbers.

const SECTION: String = "items"

var slots: int
var ink_charges_per_floor: int
## Loaded Question: questions one partial reveal may ask.
var loaded_question_questions: int


static func from_config(config: TuneConfig) -> ItemRules:
	var rules: ItemRules = ItemRules.new()
	rules.slots = config.get_int(SECTION, "slots")
	rules.ink_charges_per_floor = config.get_int(SECTION, "ink_charges_per_floor")
	rules.loaded_question_questions = config.get_int(SECTION, "loaded_question_questions")
	return rules
