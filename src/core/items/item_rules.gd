class_name ItemRules
extends RefCounted
## Item [TUNE] values (spec §9): the slot count and each item's numbers.

const SECTION: String = "items"

var slots: int
var ink_charges_per_floor: int
## Loaded Question: questions one partial reveal may ask.
var loaded_question_questions: int
## House Regular: the cooling rate. Comped Suite: the stand-up rollover share.
var house_regular_cool_rate: float
var comped_suite_rollover: float
## Quiet Hands: whether a lowered bet still pays the bet-change base. A hook
## for spec §1.1 [OPEN].
var quiet_hands_decrease_pays_base: bool
## Sleight: the Nudge's cost, percent of its base.
var sleight_nudge_pct: int
## Tell Reader: taken off each mark's base at low stakes.
var tell_reader_mark_cut: float
## Shops (§6.4): items on sale at each, the draw weight of a common, uncommon
## and rare item, and each shop's stock of Masking Tape and Cold Seals.
var shop_item_offers: int
var offer_weights: Array[int] = []
var masking_tape_stock: int
var cold_seal_stock: int
## Signature and High Roller's Nerve: percent more on a win.
var signature_bonus_pct: int
var high_roller_bonus_pct: int
## Side Pocket: the side bet cap, percent of table max.
var side_pocket_cap_pct: int
## Late Night: hands added to every floor. Comped Breakfast: unused hands
## carried to the next floor, at most.
var late_night_hands: int
var breakfast_carry_max: int


static func from_config(config: TuneConfig) -> ItemRules:
	var rules: ItemRules = ItemRules.new()
	rules.slots = config.get_int(SECTION, "slots")
	rules.ink_charges_per_floor = config.get_int(SECTION, "ink_charges_per_floor")
	rules.loaded_question_questions = config.get_int(SECTION, "loaded_question_questions")
	rules.house_regular_cool_rate = config.get_float(SECTION, "house_regular_cool_rate")
	rules.comped_suite_rollover = config.get_float(SECTION, "comped_suite_rollover")
	rules.quiet_hands_decrease_pays_base = config.get_bool(
		SECTION, "quiet_hands_decrease_pays_base"
	)
	rules.sleight_nudge_pct = config.get_int(SECTION, "sleight_nudge_pct")
	rules.tell_reader_mark_cut = config.get_float(SECTION, "tell_reader_mark_cut")
	rules.signature_bonus_pct = config.get_int(SECTION, "signature_bonus_pct")
	rules.high_roller_bonus_pct = config.get_int(SECTION, "high_roller_bonus_pct")
	rules.side_pocket_cap_pct = config.get_int(SECTION, "side_pocket_cap_pct")
	rules.late_night_hands = config.get_int(SECTION, "late_night_hands")
	rules.breakfast_carry_max = config.get_int(SECTION, "breakfast_carry_max")
	rules.shop_item_offers = config.get_int(SECTION, "shop_item_offers")
	rules.offer_weights = config.get_int_list(SECTION, "offer_weights")
	rules.masking_tape_stock = config.get_int(SECTION, "masking_tape_stock")
	rules.cold_seal_stock = config.get_int(SECTION, "cold_seal_stock")
	return rules
