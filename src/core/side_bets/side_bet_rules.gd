class_name SideBetRules
extends RefCounted
## Side bet pay tables and the stake cap (spec §8), priced for one 52-card
## deck. Every payout is n:1.

const SECTION: String = "side_bets"

## Each side bet is at most this percent of the table max.
var cap_pct: int
## Mixed pair, coloured pair.
var perfect_pairs: Array[int]
## Straight flush, three of a kind, straight, flush.
var twenty_one_plus_three: Array[int]
## The dealer busts on 3, 4, 5, 6, or 7 or more cards.
var bust_it: Array[int]
## A non-natural win by 4, 5, 6, 7, 8, 9.
var dragon_bonus: Array[int]
## A natural win. A natural tie pushes.
var dragon_natural: int
## Player Pair or Banker Pair.
var pair: int
var exact_rank: int


static func from_config(config: TuneConfig) -> SideBetRules:
	var rules: SideBetRules = SideBetRules.new()
	rules.cap_pct = config.get_int(SECTION, "cap_pct")
	rules.perfect_pairs = config.get_int_list(SECTION, "perfect_pairs")
	rules.twenty_one_plus_three = config.get_int_list(SECTION, "twenty_one_plus_three")
	rules.bust_it = config.get_int_list(SECTION, "bust_it")
	rules.dragon_bonus = config.get_int_list(SECTION, "dragon_bonus")
	rules.dragon_natural = config.get_int(SECTION, "dragon_natural")
	rules.pair = config.get_int(SECTION, "pair")
	rules.exact_rank = config.get_int(SECTION, "exact_rank")
	return rules


## The largest stake one side bet takes at a table with this max. Side Pocket
## (§9, block 13) passes its own percent.
func cap(table_max: int, percent: int = -1) -> int:
	return Money.apply_ratio(table_max, cap_pct if percent < 0 else percent, 100)
