class_name ActionKit
extends RefCounted
## What the player carries for the whole run (spec §2.4, §9): items in their
## slots, consumables, and what the items do. Items are the one source of
## effects: owning or losing one rebuilds every effect field below from the
## starting kit, and the rules read those fields.

## §2.4: the starting kit's actions and its two symbols.
const STARTING_ACTIONS: Array[ActionKind.Kind] = [
	ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.NUDGE, ActionKind.Kind.MARK
]
const STARTING_SYMBOLS: Array[int] = [0, 1]

## Owned items, first bought first. One of each, at most the slot count.
var items: Array[ItemKind.Kind] = []
var masking_tape: int = 0
var cold_seals: int = 0
## Permanent Ink charges left this floor.
var ink_charges: int = 0

# Effects, rebuilt from items.

var unlocked: Array[ActionKind.Kind] = []
## The symbol ids the player can mark with.
var symbols: Array[int] = []
## Loaded Question: questions one partial reveal may ask.
var questions_per_reveal: int = 1
## Luminous Ink: its symbols' marks add less to the heat floor.
var luminous_symbols: Array[int] = []
## Forged Papers: the heat floor is cut.
var forged_papers: bool = false
## Second Deck: card removals cost a flat price.
var flat_removals: bool = false
## Deep Read: no second window surcharge.
var deep_read: bool = false
## Poker Face: the first window acted in each hand is free.
var poker_face: bool = false
## Quiet Hands: a lowered bet doesn't count toward the multiplier. Whether
## it still pays the bet-change base is a hook (§1.1 [OPEN]).
var quiet_hands: bool = false
var quiet_hands_decrease_pays_base: bool = true
## Sleight: the Nudge's cost, percent of its base.
var nudge_cost_pct: int = 100
## Tell Reader: taken off each mark's base at low-stakes tables.
var low_stakes_mark_cut: float = 0.0
## House Regular: the cooling rate instead of the usual one; 0 for none.
var cool_rate_override: float = 0.0
## Comped Suite: the stand-up rollover share instead of the usual; 0 for none.
var stand_up_rollover_override: float = 0.0
## Pit Ledger: sitting down shows the table's cost rolls and consequence.
var pit_ledger: bool = false
## Side Pocket: the side bet cap, percent of table max; -1 for the usual.
var side_cap_pct: int = -1
## Signature and High Roller's Nerve: percent more on a win; 0 for none.
var signature_pct: int = 0
var high_roller_pct: int = 0
## Comp Slip: the session's first lost stake comes back.
var comp_slip: bool = false
## Late Night: hands added to every floor's clock.
var extra_floor_hands: int = 0
## Comped Breakfast: unused hands carried to the next floor, at most.
var carry_hands_max: int = 0

## The rules items read their numbers from, set by add_item. Fill items
## only through add_item, so it's set before an item needs it.
var _rules: ItemRules


func _init() -> void:
	_apply_items()


## §2.4: partial reveal, Nudge, and Mark with two symbols.
static func starting() -> ActionKit:
	return ActionKit.new()


## The starting kit plus every unlock item, for tests and the simulation
## harness.
static func everything() -> ActionKit:
	var kit: ActionKit = ActionKit.new()
	kit.items.assign(ItemKind.UNLOCKS.keys())
	kit._apply_items()
	return kit


func has(action: ActionKind.Kind) -> bool:
	return action in unlocked


func has_item(item: ItemKind.Kind) -> bool:
	return item in items


func has_free_slot(rules: ItemRules) -> bool:
	return items.size() < rules.slots


## Takes the item into a free slot. Refused when already owned or the slots
## are full.
func add_item(item: ItemKind.Kind, rules: ItemRules) -> bool:
	if has_item(item) or not has_free_slot(rules):
		return false
	_rules = rules
	items.append(item)
	_apply_items()
	if item == ItemKind.Kind.PERMANENT_INK:
		refill_ink()
	return true


## Permanent Ink (§9): a floor's charges, unused ones lost. None without it.
func refill_ink() -> void:
	ink_charges = _rules.ink_charges_per_floor if has_item(ItemKind.Kind.PERMANENT_INK) else 0


## Discards an owned item, freeing its slot.
func remove_item(item: ItemKind.Kind) -> bool:
	if not has_item(item):
		return false
	items.erase(item)
	_apply_items()
	refill_ink()
	return true


func _apply_items() -> void:
	unlocked = STARTING_ACTIONS.duplicate()
	symbols = STARTING_SYMBOLS.duplicate()
	questions_per_reveal = 1
	luminous_symbols = []
	forged_papers = false
	flat_removals = false
	deep_read = false
	poker_face = false
	quiet_hands = false
	quiet_hands_decrease_pays_base = true
	nudge_cost_pct = 100
	low_stakes_mark_cut = 0.0
	cool_rate_override = 0.0
	stand_up_rollover_override = 0.0
	pit_ledger = false
	side_cap_pct = -1
	signature_pct = 0
	high_roller_pct = 0
	comp_slip = false
	extra_floor_hands = 0
	carry_hands_max = 0
	for item: ItemKind.Kind in items:
		if ItemKind.UNLOCKS.has(item):
			unlocked.append(ItemKind.UNLOCKS[item])
		if ItemKind.SYMBOLS.has(item):
			symbols.append(ItemKind.SYMBOLS[item])
		match item:
			ItemKind.Kind.LUMINOUS_INK:
				luminous_symbols.append(ItemKind.SYMBOLS[item])
			ItemKind.Kind.LOADED_QUESTION:
				questions_per_reveal = _rules.loaded_question_questions
			ItemKind.Kind.FORGED_PAPERS:
				forged_papers = true
			ItemKind.Kind.SECOND_DECK:
				flat_removals = true
			ItemKind.Kind.DEEP_READ:
				deep_read = true
			ItemKind.Kind.POKER_FACE:
				poker_face = true
			ItemKind.Kind.QUIET_HANDS:
				quiet_hands = true
				quiet_hands_decrease_pays_base = _rules.quiet_hands_decrease_pays_base
			ItemKind.Kind.SLEIGHT:
				nudge_cost_pct = _rules.sleight_nudge_pct
			ItemKind.Kind.TELL_READER:
				low_stakes_mark_cut = _rules.tell_reader_mark_cut
			ItemKind.Kind.HOUSE_REGULAR:
				cool_rate_override = _rules.house_regular_cool_rate
			ItemKind.Kind.COMPED_SUITE:
				stand_up_rollover_override = _rules.comped_suite_rollover
			ItemKind.Kind.PIT_LEDGER:
				pit_ledger = true
			ItemKind.Kind.SIDE_POCKET:
				side_cap_pct = _rules.side_pocket_cap_pct
			ItemKind.Kind.SIGNATURE:
				signature_pct = _rules.signature_bonus_pct
			ItemKind.Kind.HIGH_ROLLERS_NERVE:
				high_roller_pct = _rules.high_roller_bonus_pct
			ItemKind.Kind.COMP_SLIP:
				comp_slip = true
			ItemKind.Kind.LATE_NIGHT:
				extra_floor_hands = _rules.late_night_hands
			ItemKind.Kind.COMPED_BREAKFAST:
				carry_hands_max = _rules.breakfast_carry_max
	symbols.sort()
