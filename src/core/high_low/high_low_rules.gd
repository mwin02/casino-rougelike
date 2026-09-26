class_name HighLowRules
extends RefCounted
## High or Low pricing (spec §3.3). Each correct call pays true odds against
## the remaining cards, less the house cut, held between a floor and the
## per-call cap. The chain value is capped at a multiple of the stake.
## Every value rounds down to whole dollars (§6.2).

const SECTION: String = "high_low"

var cut_pct: int
## A correct call multiplies the chain value by at least this percent.
var min_call_payout_pct: int
## ...and by at most this percent.
var max_call_payout_pct: int
## The chain value never passes this percent of the stake.
var max_chain_pct: int


static func from_config(config: TuneConfig) -> HighLowRules:
	var rules: HighLowRules = HighLowRules.new()
	rules.cut_pct = config.get_int(SECTION, "cut_pct")
	rules.min_call_payout_pct = config.get_int(SECTION, "min_call_payout_pct")
	rules.max_call_payout_pct = config.get_int(SECTION, "max_call_payout_pct")
	rules.max_chain_pct = config.get_int(SECTION, "max_chain_pct")
	return rules


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
