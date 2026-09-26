class_name StandardDeck
extends RefCounted
## The standard 52-card deck. Block 1 replaces this with the player's deck.


static func build() -> Array[Card]:
	var cards: Array[Card] = []
	for suit: int in Card.Suit.values():
		for rank: int in range(1, 14):
			cards.append(Card.new(rank, suit as Card.Suit))
	return cards


## A fresh deck in a Fisher-Yates order drawn from rng.
static func shuffled(rng: RandomNumberGenerator) -> Array[Card]:
	var cards: Array[Card] = build()
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Card = cards[i]
		cards[i] = cards[j]
		cards[j] = swap
	return cards
