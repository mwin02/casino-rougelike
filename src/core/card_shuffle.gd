class_name CardShuffle
extends RefCounted
## Fisher-Yates shuffle. The deck reshuffles every hand (spec §4.1).


## A new array holding cards in an order drawn from rng. The input is untouched.
static func shuffled(cards: Array[Card], rng: RandomNumberGenerator) -> Array[Card]:
	var result: Array[Card] = cards.duplicate()
	for i: int in range(result.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Card = result[i]
		result[i] = result[j]
		result[j] = swap
	return result
