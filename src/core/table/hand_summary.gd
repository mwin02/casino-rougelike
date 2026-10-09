class_name HandSummary
extends RefCounted
## What one hand at a table came to (spec §1.4): its dollars, its heat, and
## the efficiency line "+$24,000 for 6 heat". Heat is the hand's own (its
## actions and the multiplier); the table's cooling is kept apart.

## The lines that are the hand's own heat.
const HAND_KINDS: Array[HeatLine.Kind] = [
	HeatLine.Kind.ACTION,
	HeatLine.Kind.SIDE_BET,
	HeatLine.Kind.BET_CHANGE,
	HeatLine.Kind.MULTIPLIER,
]

## Dollars won (or lost) this hand, side bets included.
var net: int
## The side bets' share of net, and the bets as they settled (§8).
var side_net: int = 0
var side_bets: Array[SideBet] = []
## Dollars a Stingy house signature kept from the winnings (§5.3), already
## taken out of net.
var house_cut: int = 0
## Dollars items added to net (§9), each its own line.
var bonuses: Array[ItemBonus] = []
## Every line the hand produced, in order: actions, multiplier, then the
## table's own.
var lines: Array[HeatLine] = []
## Action, side-bet, bet-change and multiplier heat.
var heat: float = 0.0
## Heat the table shed after the hand (negative), or 0.
var cooling: float = 0.0
## No actions and no bet changes (§1.6).
var straight: bool


func _init(p_net: int, p_lines: Array[HeatLine], p_straight: bool) -> void:
	net = p_net
	lines = p_lines
	straight = p_straight
	for line: HeatLine in lines:
		if line.kind in HAND_KINDS:
			heat += line.amount
		elif line.kind == HeatLine.Kind.COOLING:
			cooling += line.amount


## False when the hand cost no heat, so there is no rate to show.
func has_rate() -> bool:
	return heat > 0.0


## Dollars won (or lost) per point of heat. 0 without a rate.
func dollars_per_heat() -> float:
	return net / heat if has_rate() else 0.0
