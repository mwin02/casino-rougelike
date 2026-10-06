class_name DeckRules
extends RefCounted
## Deck [TUNE] values (spec §4.1, §4.2), deck service prices included.

const SECTION: String = "deck"
const SHOP_SECTION: String = "shop"

## Removals stop at this many cards.
var min_size: int
## §4.2: heat floor added per edit of each kind, per marked card, and per
## Luminous Ink mark; Forged Papers' cut.
var floor_per_removal: float
var floor_per_addition: float
var floor_per_rummage: float
var floor_per_touch_up: float
var floor_per_full_reforge: float
var floor_per_cold_seal: float
var floor_per_ink: float
var floor_per_mark: float
var floor_per_luminous_mark: float
var forged_papers_floor_cut: float
## §4.1: service prices, percents of the floor quota. A removal adds
## removal_step_pct for each removal earlier in the run.
var removal_pct: int
var removal_step_pct: int
var addition_pct: int
var rummage_pct: int
var touch_up_pct: int
var full_reforge_pct: int
var clear_mark_pct: int


static func from_config(config: TuneConfig) -> DeckRules:
	var rules: DeckRules = DeckRules.new()
	rules.min_size = config.get_int(SECTION, "min_size")
	rules.floor_per_removal = config.get_float(SECTION, "floor_per_removal")
	rules.floor_per_addition = config.get_float(SECTION, "floor_per_addition")
	rules.floor_per_rummage = config.get_float(SECTION, "floor_per_rummage")
	rules.floor_per_touch_up = config.get_float(SECTION, "floor_per_touch_up")
	rules.floor_per_full_reforge = config.get_float(SECTION, "floor_per_full_reforge")
	rules.floor_per_cold_seal = config.get_float(SECTION, "floor_per_cold_seal")
	rules.floor_per_ink = config.get_float(SECTION, "floor_per_ink")
	rules.floor_per_mark = config.get_float(SECTION, "floor_per_mark")
	rules.floor_per_luminous_mark = config.get_float(SECTION, "floor_per_luminous_mark")
	rules.forged_papers_floor_cut = config.get_float(SECTION, "forged_papers_floor_cut")
	rules.removal_pct = config.get_int(SHOP_SECTION, "removal_pct")
	rules.removal_step_pct = config.get_int(SHOP_SECTION, "removal_step_pct")
	rules.addition_pct = config.get_int(SHOP_SECTION, "addition_pct")
	rules.rummage_pct = config.get_int(SHOP_SECTION, "rummage_pct")
	rules.touch_up_pct = config.get_int(SHOP_SECTION, "touch_up_pct")
	rules.full_reforge_pct = config.get_int(SHOP_SECTION, "full_reforge_pct")
	rules.clear_mark_pct = config.get_int(SHOP_SECTION, "clear_mark_pct")
	return rules


## The floor one edit of this kind adds.
func floor_per_edit(kind: DeckEdit.Kind) -> float:
	var steps: Dictionary[DeckEdit.Kind, float] = {
		DeckEdit.Kind.REMOVE: floor_per_removal,
		DeckEdit.Kind.ADD: floor_per_addition,
		DeckEdit.Kind.REFORGE_RUMMAGE: floor_per_rummage,
		DeckEdit.Kind.REFORGE_TOUCH_UP: floor_per_touch_up,
		DeckEdit.Kind.REFORGE_FULL: floor_per_full_reforge,
		DeckEdit.Kind.COLD_SEAL: floor_per_cold_seal,
		DeckEdit.Kind.PERMANENT_INK: floor_per_ink,
	}
	return steps[kind]
