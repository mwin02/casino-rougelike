class_name HighLowRules
extends RefCounted
## High or Low pricing (spec §3.3). Each correct call pays true odds against
## the remaining cards, less the house cut, held between a floor and the
## per-call cap. The chain value is capped at a multiple of the stake.
## Every value rounds down to whole dollars (§6.2).

const SECTION: String = "high_low"
## Where the ace sits under the aces-high house rule: above the king.
const ACE_HIGH: int = 14

var cut_pct: int
## A correct call multiplies the chain value by at least this percent.
var min_call_payout_pct: int
## ...and by at most this percent.
var max_call_payout_pct: int
## The chain value never passes this percent of the stake.
var max_chain_pct: int
## Aces are low (§3.3) unless the aces-high house rule ranks them above the
## king.
var aces_high: bool
## §3.3: reads at High or Low. No full reveal; look ahead only in the first
## call's window, showing this many cards. The first call can be known, the
## chain can't.
var full_reveal_allowed: bool
var look_ahead_first_window_only: bool
var look_ahead_cards: int


static func from_config(config: TuneConfig) -> HighLowRules:
	var rules: HighLowRules = HighLowRules.new()
	rules.cut_pct = config.get_int(SECTION, "cut_pct")
	rules.min_call_payout_pct = config.get_int(SECTION, "min_call_payout_pct")
	rules.max_call_payout_pct = config.get_int(SECTION, "max_call_payout_pct")
	rules.max_chain_pct = config.get_int(SECTION, "max_chain_pct")
	rules.aces_high = config.get_bool(SECTION, "aces_high")
	rules.full_reveal_allowed = config.get_bool(SECTION, "full_reveal_allowed")
	rules.look_ahead_first_window_only = config.get_bool(SECTION, "look_ahead_first_window_only")
	rules.look_ahead_cards = config.get_int(SECTION, "look_ahead_cards")
	return rules


## A rank's place in the order calls compare by: higher beats lower.
func order(rank: int) -> int:
	return ACE_HIGH if aces_high and rank == 1 else rank


## The chain value after a correct call, where winners of the remaining cards
## would have won it. A call with no winners (only a manipulated card wins it)
## pays the per-call cap.
func call_value(value: int, winners: int, remaining: int) -> int:
	var ceiling: int = Money.apply_ratio(value, max_call_payout_pct, 100)
	if winners <= 0:
		return ceiling
	var priced: int = Money.apply_ratio(value, remaining * (100 - cut_pct), winners * 100)
	var floor_value: int = Money.apply_ratio(value, min_call_payout_pct, 100)
	return clampi(priced, floor_value, ceiling)


func chain_cap(stake: int) -> int:
	return Money.apply_ratio(stake, max_chain_pct, 100)


## A tie ends the chain and keeps half its value.
static func tie_value(value: int) -> int:
	return Money.apply_ratio(value, 1, 2)
