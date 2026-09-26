extends GdUnitTestSuite
## The player's owned deck: composition, edits, marks (spec §4).

const MIN_SIZE: int = 20

var _deck: Deck


func before_test() -> void:
	_deck = Deck.standard(MIN_SIZE)


func _id_of(code: String) -> int:
	for card: Card in _deck.cards():
		if card.short_name() == code:
			return card.id
	return Card.NO_ID


func test_standard_deck_has_52_distinct_cards_with_unique_ids() -> void:
	assert_int(_deck.size()).is_equal(52)
	assert_int(_deck.composition().size()).is_equal(52)
	var ids: Dictionary[int, bool] = {}
	for card: Card in _deck.cards():
		ids[card.id] = true
	assert_int(ids.size()).is_equal(52)


func test_cards_returns_copies() -> void:
	_deck.cards()[0].rank = 5
	_deck.cards()[0].symbol = 1
	assert_dict(_deck.composition()).is_equal(Deck.standard(MIN_SIZE).composition())
	assert_int(_deck.marked_count()).is_equal(0)


func test_remove_card_records_an_edit() -> void:
	assert_bool(_deck.remove_card(_id_of("7H"))).is_true()
	assert_int(_deck.size()).is_equal(51)
	assert_bool(_deck.composition().has("7H")).is_false()
	assert_int(_deck.edit_count(DeckEdit.Kind.REMOVE)).is_equal(1)


func test_remove_unknown_card_fails() -> void:
	assert_bool(_deck.remove_card(999)).is_false()
	assert_int(_deck.edits().size()).is_equal(0)


func test_minimum_deck_size_blocks_removal() -> void:
	while _deck.size() > MIN_SIZE:
		assert_bool(_deck.remove_card(_deck.cards()[0].id)).is_true()
	var before: Dictionary[String, int] = _deck.composition()
	assert_bool(_deck.remove_card(_deck.cards()[0].id)).is_false()
	assert_int(_deck.size()).is_equal(MIN_SIZE)
	assert_dict(_deck.composition()).is_equal(before)
	assert_int(_deck.edit_count(DeckEdit.Kind.REMOVE)).is_equal(52 - MIN_SIZE)


func test_add_card_gets_a_fresh_id() -> void:
	var added: Card = _deck.add_card(1, Card.Suit.SPADES)
	assert_int(_deck.size()).is_equal(53)
	assert_int(_deck.composition()["AS"]).is_equal(2)
	assert_int(added.id).is_not_equal(_id_of("AS"))
	assert_int(_deck.edit_count(DeckEdit.Kind.ADD)).is_equal(1)


func test_edits_count_cumulatively() -> void:
	# Spec §4.2: removing a card and adding it back is two edits.
	_deck.remove_card(_id_of("7H"))
	_deck.add_card(7, Card.Suit.HEARTS)
	assert_dict(_deck.composition()).is_equal(Deck.standard(MIN_SIZE).composition())
	assert_int(_deck.edits().size()).is_equal(2)


# gdlint: ignore=unused-argument
func test_reforge_keeps_card_id_and_mark(tier: DeckEdit.Kind, test_parameters: Array = [
	[DeckEdit.Kind.REFORGE_RUMMAGE],
	[DeckEdit.Kind.REFORGE_TOUCH_UP],
	[DeckEdit.Kind.REFORGE_FULL],
]) -> void:
	var id: int = _id_of("9C")
	_deck.mark(id, 1)
	assert_bool(_deck.reforge(id, 10, Card.Suit.CLUBS, tier)).is_true()
	var card: Card = _deck.card(id)
	assert_str(card.short_name()).is_equal("10C")
	assert_int(card.symbol).is_equal(1)
	assert_int(_deck.edit_count(tier)).is_equal(1)
	assert_int(_deck.edits()[0].card_id).is_equal(id)


func test_reforge_rejects_a_non_reforge_kind() -> void:
	assert_bool(_deck.reforge(_id_of("9C"), 10, Card.Suit.CLUBS, DeckEdit.Kind.REMOVE)).is_false()
	assert_int(_deck.edits().size()).is_equal(0)


func test_ink_is_a_permanent_edit() -> void:
	var id: int = _id_of("KD")
	assert_bool(_deck.ink(id, 12, Card.Suit.SPADES)).is_true()
	assert_str(_deck.card(id).short_name()).is_equal("QS")
	assert_int(_deck.edit_count(DeckEdit.Kind.PERMANENT_INK)).is_equal(1)


func test_marks_overwrite_and_clear() -> void:
	var id: int = _id_of("AH")
	_deck.mark(id, 0)
	_deck.mark(id, 1)
	assert_int(_deck.card(id).symbol).is_equal(1)
	assert_int(_deck.marked_count()).is_equal(1)
	assert_bool(_deck.clear_mark(id)).is_true()
	assert_int(_deck.marked_count()).is_equal(0)


func test_marks_are_not_edits() -> void:
	_deck.mark(_id_of("AH"), 0)
	assert_int(_deck.edits().size()).is_equal(0)


func test_marks_survive_reshuffles() -> void:
	var id: int = _id_of("AH")
	_deck.mark(id, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 3:
		for card: Card in CardShuffle.shuffled(_deck.dealing_cards(ManipulationLayer.new()), rng):
			if card.id == id:
				assert_int(card.symbol).is_equal(0)
	assert_int(_deck.card(id).symbol).is_equal(0)


func test_dealing_cards_applies_the_layer_to_copies() -> void:
	var id: int = _id_of("5S")
	var layer: ManipulationLayer = ManipulationLayer.new()
	layer.change(id, 6, Card.Suit.SPADES, ManipulationLayer.Duration.SESSION)
	var dealt: Array[Card] = _deck.dealing_cards(layer)
	var names: Array[String] = []
	for card: Card in dealt:
		names.append(card.short_name())
	assert_bool(names.has("5S")).is_false()
	assert_int(names.count("6S")).is_equal(2)
	for card: Card in dealt:
		card.rank = 2
	assert_dict(_deck.composition()).is_equal(Deck.standard(MIN_SIZE).composition())
