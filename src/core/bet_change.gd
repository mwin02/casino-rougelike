class_name BetChange
extends RefCounted
## One bet change in a hand (spec §1.3). Blackjack doubles, splits and
## insurance (§3.1) and baccarat side switches (§3.2) all feed the heat
## multiplier through these. A side switch moves no dollars; heat counts it
## as the maximum possible bet change, r = 3 (block 6).

enum Kind { DOUBLE, SPLIT, INSURANCE, SIDE_SWITCH }

## hand_index for a change that covers the round, not a hand.
const NO_HAND: int = -1

var kind: Kind
## Dollars added to the total bet.
var amount: int
## The hand the change belongs to (the new hand, for a split), or NO_HAND.
var hand_index: int


func _init(p_kind: Kind, p_amount: int, p_hand_index: int) -> void:
	kind = p_kind
	amount = p_amount
	hand_index = p_hand_index
