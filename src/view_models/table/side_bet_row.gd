class_name SideBetRow
extends RefCounted
## One side bet on the real table's stake window (spec §8): what wins it,
## what it pays, its stake, and which of its controls can be pressed.

var kind: SideBetKind.Kind
var name: String
## What has to happen for it to win.
var wins: String
## Each payout as a label and its odds: ["Flush", "5:1"].
var pays: Array[PackedStringArray] = []
var on: bool
## Dollars on its spot, shown as chips. 0 while it's off.
var stake: int
## Its stake, or the stake it would come on with.
var stake_text: String
var can_toggle: bool
var can_lower: bool
var can_raise: bool
## Why it's off: "OFF", or "NOT ENOUGH" when the bankroll can't cover it.
var off_text: String
## Dragon Bonus and Pair ride on a side.
var picks_side: bool
var side: BaccaratRound.BetSide
## Exact rank calls a rank.
var picks_rank: bool
var rank: int


## The pay table of kind, best first where the canvas lists it so.
static func pays_of(kind: SideBetKind.Kind, rules: SideBetRules) -> Array[PackedStringArray]:
	match kind:
		SideBetKind.Kind.PERFECT_PAIRS:
			return _table(["Mixed", "Coloured"], rules.perfect_pairs)
		SideBetKind.Kind.TWENTY_ONE_PLUS_THREE:
			var hands: Array[String] = ["Straight flush", "Trips", "Straight", "Flush"]
			return _table(hands, rules.twenty_one_plus_three)
		SideBetKind.Kind.BUST_IT:
			return _table(["3 cards", "4", "5", "6", "7+"], rules.bust_it)
		SideBetKind.Kind.DRAGON_BONUS:
			# The rules list margins of 4 up to 9; the screen leads with the best.
			var odds: Array[int] = rules.dragon_bonus.duplicate()
			odds.reverse()
			var by: Array[PackedStringArray] = _table(["By 9", "8", "7", "6", "5", "4"], odds)
			by.push_front(_pay("Natural", rules.dragon_natural))
			return by
		SideBetKind.Kind.PAIR:
			return [_pay("Pair", rules.pair)]
	return [_pay("Pays", rules.exact_rank)]


static func _table(labels: Array[String], odds: Array[int]) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	for i: int in labels.size():
		result.append(_pay(labels[i], odds[i]))
	return result


static func _pay(label: String, odds: int) -> PackedStringArray:
	return [label, "%d:1" % odds]
