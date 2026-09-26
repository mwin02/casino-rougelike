class_name TuneSchema
extends RefCounted
## Every key config/tune.cfg must hold, and its type. TuneConfig checks the
## file against this on load: a missing key, a wrong type, a list of the wrong
## length, or a key not listed here is an error.
##
## Money ratios are integer percents (fed to Money.apply_ratio, so they stay
## exact). Heat numbers and probabilities are floats: write them with a
## decimal point.
##
## Not here yet, added by the block that builds them: stake_factor (block 6),
## deck service prices (block 11), marker interest and pit boss scaling
## (blocks 12, 14), the side bet cap (block 10), and the two [OPEN] items
## (spec §5.3, §6.3).

enum Kind { INT, FLOAT, BOOL, INT_LIST, FLOAT_LIST }

## Floors in a run (spec §5.3). Per-floor lists hold one entry per floor.
const FLOORS: int = 5

## Lists that pair up entry by entry: same section, same length, at least
## this many entries. [section, key, key, minimum length].
const PAIRED: Array[Array] = [
	["heat", "multiplier_ratios", "multiplier_values", 2],
]

## section -> key -> [Kind, list length (0: any)].
const KEYS: Dictionary[String, Dictionary] = {
	"heat": {
		# §1.1: m(r) as points, linear between.
		"multiplier_ratios": [Kind.FLOAT_LIST, 0],
		"multiplier_values": [Kind.FLOAT_LIST, 0],
		# §1.2: per-table base cost roll, ± this share of the center.
		"base_cost_spread": [Kind.FLOAT, 0],
		# §1.3: adjust limits against the opening bet.
		"max_raise_pct": [Kind.INT, 0],
		"min_decrease_pct": [Kind.INT, 0],
	},
	"cooling": {
		"cool_rate": [Kind.FLOAT, 0],
	},
	"actions": {
		# §2.3 base cost centers (blackjack reference).
		"partial_reveal": [Kind.FLOAT, 0],
		"mark": [Kind.FLOAT, 0],
		"mark_step": [Kind.FLOAT, 0],
		"full_reveal": [Kind.FLOAT, 0],
		"look_ahead": [Kind.FLOAT, 0],
		"recolour": [Kind.FLOAT, 0],
		"nudge": [Kind.FLOAT, 0],
		"switch": [Kind.FLOAT, 0],
		"palm": [Kind.FLOAT, 0],
	},
	"blackjack": {
		"bust_threshold": [Kind.INT, 0],
		"natural_payout_num": [Kind.INT, 0],
		"natural_payout_den": [Kind.INT, 0],
		"dealer_stand": [Kind.INT, 0],
		"dealer_hits_soft_17": [Kind.BOOL, 0],
	},
	"high_low": {
		"cut_pct": [Kind.INT, 0],
		"max_call_payout_pct": [Kind.INT, 0],
		"max_chain_pct": [Kind.INT, 0],
		"reveal_cost_factor": [Kind.FLOAT, 0],
	},
	"deck": {
		"min_size": [Kind.INT, 0],
		# §4.2 heat floor per edit, per mark, and Forged Papers.
		"floor_per_removal": [Kind.FLOAT, 0],
		"floor_per_addition": [Kind.FLOAT, 0],
		"floor_per_rummage": [Kind.FLOAT, 0],
		"floor_per_touch_up": [Kind.FLOAT, 0],
		"floor_per_full_reforge": [Kind.FLOAT, 0],
		"floor_per_cold_seal": [Kind.FLOAT, 0],
		"floor_per_ink": [Kind.FLOAT, 0],
		"floor_per_mark": [Kind.FLOAT, 0],
		"floor_per_luminous_mark": [Kind.FLOAT, 0],
		"forged_papers_floor_cut": [Kind.FLOAT, 0],
	},
	"floors": {
		# §6.3, one entry per floor.
		"start_bankroll": [Kind.INT, 0],
		"quotas": [Kind.INT_LIST, FLOORS],
		"low_stakes_min": [Kind.INT_LIST, FLOORS],
		"low_stakes_max": [Kind.INT_LIST, FLOORS],
		"high_stakes_min": [Kind.INT_LIST, FLOORS],
		"high_stakes_max": [Kind.INT_LIST, FLOORS],
	},
	"clock": {
		"hands_per_floor": [Kind.INT, 0],
		"extra_hands_cap": [Kind.INT, 0],
	},
	"shop": {
		# Shares of the current floor quota (§6.4, §4.1, §9).
		"common_pct": [Kind.INT, 0],
		"uncommon_pct": [Kind.INT, 0],
		"rare_pct": [Kind.INT, 0],
		"rummage_pct": [Kind.INT, 0],
		"touch_up_pct": [Kind.INT, 0],
		"full_reforge_pct": [Kind.INT, 0],
		"masking_tape_pct": [Kind.INT, 0],
		"cold_seal_pct": [Kind.INT, 0],
	},
	"run_heat": {
		"stand_up_rollover": [Kind.FLOAT, 0],
		"elevator_shed_min": [Kind.FLOAT, 0],
		"elevator_shed_max": [Kind.FLOAT, 0],
		"cash_out_shed_per_hand": [Kind.FLOAT, 0],
	},
	"consequences": {
		# §7.2: P(house deck swap), one entry per floor.
		"house_swap_chance": [Kind.FLOAT_LIST, FLOORS],
	},
	"pit_boss": {
		"watched_from": [Kind.FLOAT, 0],
	},
	"items": {
		"slots": [Kind.INT, 0],
		"ink_charges_per_floor": [Kind.INT, 0],
	},
	"marker": {
		"max_share_pct": [Kind.INT, 0],
	},
	"debug": {
		# Not a [TUNE] value: the fixed bet for the block 0 debug table.
		"debug_bet": [Kind.INT, 0],
	},
}
