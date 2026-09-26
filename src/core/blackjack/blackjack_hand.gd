class_name BlackjackHand
extends RefCounted
## One blackjack hand. Each ace counts 11 while the total stays under the
## bust threshold (so up to 22 at the default 23), otherwise 1.

## Extra value of one ace counted high.
const ACE_BONUS: int = 10

var cards: Array[Card] = []

var _rules: BlackjackRules


func _init(rules: BlackjackRules) -> void:
	_rules = rules


func add(card: Card) -> void:
	cards.append(card)


func total() -> int:
	return _hard_total() + _aces_high() * ACE_BONUS


## True when at least one ace is being counted as 11.
func is_soft() -> bool:
	return _aces_high() > 0


func is_bust() -> bool:
	return total() >= _rules.bust_threshold


## Exactly two cards: an ace and a ten-value card.
func is_natural() -> bool:
	if cards.size() != 2:
		return false
	var first: Card = cards[0]
	var second: Card = cards[1]
	return (first.is_ace() and _value(second) == 10) or (second.is_ace() and _value(first) == 10)


func _hard_total() -> int:
	var sum: int = 0
	for card: Card in cards:
		sum += _value(card)
	return sum


## How many aces count 11. With bust at 23, two can (A+A is soft 22).
func _aces_high() -> int:
	var aces: int = 0
	for card: Card in cards:
		if card.is_ace():
			aces += 1
	var high: int = 0
	var sum: int = _hard_total()
	while high < aces and sum + ACE_BONUS <= _rules.max_total():
		sum += ACE_BONUS
		high += 1
	return high


static func _value(card: Card) -> int:
	return mini(card.rank, 10)
