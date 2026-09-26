extends GdUnitTestSuite


func test_new_card_is_unmarked_and_has_no_id() -> void:
	var card: Card = Card.new(1, Card.Suit.SPADES)
	assert_int(card.id).is_equal(Card.NO_ID)
	assert_int(card.symbol).is_equal(Card.NO_SYMBOL)
	assert_bool(card.is_marked()).is_false()


func test_copy_keeps_identity_and_is_independent() -> void:
	var card: Card = Card.new(12, Card.Suit.HEARTS)
	card.id = 7
	card.symbol = 1
	var copied: Card = card.copy()
	copied.rank = 13
	copied.symbol = 0
	assert_int(card.rank).is_equal(12)
	assert_int(card.symbol).is_equal(1)
	assert_int(copied.id).is_equal(7)
	assert_int(copied.suit).is_equal(Card.Suit.HEARTS)
