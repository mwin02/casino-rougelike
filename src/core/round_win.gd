class_name RoundWin
extends RefCounted
## One stake a round paid out on, and the player's cards that won it, for the
## items that pay more on a win (spec §9).

## Dollars won on the stake, its return not included.
var winnings: int
var cards: Array[Card]


func _init(p_winnings: int, p_cards: Array[Card]) -> void:
	winnings = p_winnings
	cards = p_cards


func has_marked_card() -> bool:
	return cards.any(func(card: Card) -> bool: return card.is_marked())
