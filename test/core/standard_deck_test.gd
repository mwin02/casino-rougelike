extends GdUnitTestSuite


func _names(cards: Array[Card]) -> Array[String]:
	var names: Array[String] = []
	for card: Card in cards:
		names.append(card.short_name())
	return names


func test_standard_deck_has_52_distinct_cards() -> void:
	var names: Array[String] = _names(StandardDeck.build())
	assert_int(names.size()).is_equal(52)
	var unique: Dictionary[String, bool] = {}
	for card_name: String in names:
		unique[card_name] = true
	assert_int(unique.size()).is_equal(52)


func test_same_seed_gives_same_shuffle() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	assert_array(_names(StandardDeck.shuffled(a))).is_equal(_names(StandardDeck.shuffled(b)))


func test_shuffle_changes_order() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	assert_array(_names(StandardDeck.shuffled(rng))).is_not_equal(_names(StandardDeck.build()))
