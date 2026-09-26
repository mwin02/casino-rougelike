class_name BlackjackHand
extends RefCounted
## One blackjack hand. Each ace counts 11 while the total stays under the
## bust threshold (so up to 22 at the default 23), otherwise 1.

enum Outcome { NONE, NATURAL, WIN, LOSE, PUSH, PLAYER_BUST, DEALER_BUST }

## Extra value of one ace counted high.
const ACE_BONUS: int = 10

var cards: Array[Card] = []
## Dollars riding on this hand, doubles included.
var stake: int = 0
## True once the player stands, or after a double's one card.
var stood: bool = false
var doubled: bool = false
var outcome: Outcome = Outcome.NONE

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


## No more player decisions: stood, doubled, or bust.
func is_done() -> bool:
	return stood or is_bust()


## Dollars won (positive) or lost (negative) once the outcome is set.
func net() -> int:
	match outcome:
		Outcome.NATURAL:
			return Money.apply_ratio(stake, _rules.natural_payout_num, _rules.natural_payout_den)
		Outcome.WIN, Outcome.DEALER_BUST:
			return stake
		Outcome.LOSE, Outcome.PLAYER_BUST:
			return -stake
	return 0


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
