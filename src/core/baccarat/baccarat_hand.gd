class_name BaccaratHand
extends RefCounted
## One side's baccarat hand (spec §3.2). Aces count 1, 2–9 their face value,
## tens and faces 0; the total is the last digit of the sum.

## Two-card totals at or above this are naturals.
const NATURAL_MIN: int = 8

var cards: Array[Card] = []


func add(card: Card) -> void:
	cards.append(card)


func total() -> int:
	var sum: int = 0
	for card: Card in cards:
		sum += value(card)
	return sum % 10


## A two-card 8 or 9.
func is_natural() -> bool:
	return cards.size() == 2 and total() >= NATURAL_MIN


## The third card's value, or BaccaratRules.NO_THIRD.
func third_value() -> int:
	if cards.size() < 3:
		return BaccaratRules.NO_THIRD
	return value(cards[2])


static func value(card: Card) -> int:
	return card.rank if card.rank < 10 else 0
