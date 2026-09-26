class_name BetChange
extends RefCounted
## One change to a blackjack hand's total bet (spec §1.3, §3.1). Doubles,
## splits and insurance all feed the heat multiplier through these.

enum Kind { DOUBLE, SPLIT, INSURANCE }

## hand_index for insurance, which covers the round, not a hand.
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
