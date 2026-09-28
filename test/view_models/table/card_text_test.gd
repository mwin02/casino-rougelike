extends GdUnitTestSuite
## Cards as the debug table writes them: letter codes, ?? face down, a mark's
## symbol even face down (spec §2.5), and a tape tag on taped cards (§2.3).


func _card(code: String, symbol: int = Card.NO_SYMBOL) -> Card:
	var card: Card = Card.parse(code)
	card.symbol = symbol
	return card


func test_face_up() -> void:
	assert_str(CardText.name(_card("10H"), false, false)).is_equal("10H")


func test_face_down() -> void:
	assert_str(CardText.name(_card("10H"), true, false)).is_equal("??")


func test_marked_card_shows_its_symbol() -> void:
	assert_str(CardText.name(_card("7D", 0), false, false)).is_equal("7D*1")


func test_marked_card_shows_its_symbol_face_down() -> void:
	assert_str(CardText.name(_card("7D", 1), true, false)).is_equal("??*2")


func test_taped_card_wears_tape() -> void:
	assert_str(CardText.name(_card("7D"), false, true)).is_equal("7D[T]")


func test_taped_card_wears_tape_face_down() -> void:
	assert_str(CardText.name(_card("7D", 0), true, true)).is_equal("??*1[T]")


func test_symbol_names_count_from_one() -> void:
	assert_str(CardText.symbol_name(0)).is_equal("*1")
	assert_str(CardText.symbol_name(2)).is_equal("*3")
