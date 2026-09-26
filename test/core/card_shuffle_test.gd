extends GdUnitTestSuite


func _names(cards: Array[Card]) -> Array[String]:
	var names: Array[String] = []
	for card: Card in cards:
		names.append(card.short_name())
	return names


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_same_seed_gives_same_shuffle() -> void:
	var cards: Array[Card] = Deck.standard(20).cards()
	var a: Array[Card] = CardShuffle.shuffled(cards, _seeded(12345))
	var b: Array[Card] = CardShuffle.shuffled(cards, _seeded(12345))
	assert_array(_names(a)).is_equal(_names(b))


func test_shuffle_changes_order_and_keeps_cards() -> void:
	var cards: Array[Card] = Deck.standard(20).cards()
	var shuffled: Array[Card] = CardShuffle.shuffled(cards, _seeded(12345))
	assert_array(_names(shuffled)).is_not_equal(_names(cards))
	assert_array(_names(shuffled)).contains_exactly_in_any_order(_names(cards))


func test_shuffle_leaves_input_order_alone() -> void:
	var cards: Array[Card] = Deck.standard(20).cards()
	var before: Array[String] = _names(cards)
	CardShuffle.shuffled(cards, _seeded(12345))
	assert_array(_names(cards)).is_equal(before)
