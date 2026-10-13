extends GdUnitTestSuite
## A Switch can't be kept, and keeping a Nudge, Recolour or Palm on a card
## that was also switched keeps only that change, on the card it was made to
## (spec §2.3).

const MIN_SIZE: int = 20

var _deck: Deck
var _layer: ManipulationLayer


func before_test() -> void:
	_deck = Deck.standard(MIN_SIZE)
	_layer = ManipulationLayer.new()


func _id_of(code: String) -> int:
	for card: Card in _deck.cards():
		if card.short_name() == code:
			return card.id
	return Card.NO_ID


func _reads(code: String) -> String:
	return _layer.apply_to(_deck.card(_id_of(code))).short_name()


## Switches two cards as they read now.
func _switch(a_code: String, b_code: String) -> void:
	var a: Card = _layer.apply_to(_deck.card(_id_of(a_code)))
	var b: Card = _layer.apply_to(_deck.card(_id_of(b_code)))
	_layer.switch_cards(a, b)


func test_a_switch_cant_be_taped() -> void:
	_switch("KS", "4D")
	assert_bool(_layer.has_hand_change(_id_of("KS"))).is_false()
	assert_bool(_layer.tape(_id_of("KS"))).is_false()
	_layer.end_hand()
	assert_str(_reads("KS")).is_equal("KS")
	assert_str(_reads("4D")).is_equal("4D")


func test_taping_a_nudged_then_switched_card_keeps_only_the_nudge() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_switch("9H", "4D")
	assert_str(_reads("4D")).is_equal("10H")
	assert_bool(_layer.has_hand_change(_id_of("9H"))).is_false()
	assert_bool(_layer.tape(_id_of("4D"))).is_true()
	assert_str(_reads("4D")).is_equal("10H")
	assert_bool(_layer.is_taped(_id_of("4D"))).is_true()
	_layer.end_hand()
	assert_str(_reads("9H")).is_equal("10H")
	assert_str(_reads("4D")).is_equal("4D")
	assert_bool(_layer.is_taped(_id_of("9H"))).is_true()


func test_taping_a_switched_then_nudged_card_keeps_only_the_nudge() -> void:
	_switch("KS", "4D")
	_layer.change(_id_of("KS"), 5, Card.Suit.DIAMONDS)
	assert_bool(_layer.tape(_id_of("KS"))).is_true()
	_layer.end_hand()
	assert_str(_reads("4D")).is_equal("5D")
	assert_str(_reads("KS")).is_equal("KS")


func test_a_kept_change_cant_be_kept_again_through_a_switch() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_switch("9H", "4D")
	_layer.tape(_id_of("4D"))
	assert_bool(_layer.has_hand_change(_id_of("4D"))).is_false()
	assert_bool(_layer.tape(_id_of("4D"))).is_false()


func test_a_switch_cant_be_made_permanent() -> void:
	_switch("KS", "4D")
	assert_bool(_layer.make_permanent(_id_of("KS"), _deck, DeckEdit.Kind.COLD_SEAL)).is_false()
	assert_int(_deck.edits().size()).is_equal(0)


func test_sealing_a_nudged_then_switched_card_edits_only_the_nudged_card() -> void:
	var nine: int = _id_of("9H")
	var four: int = _id_of("4D")
	_layer.change(nine, 10, Card.Suit.HEARTS)
	_switch("9H", "4D")
	assert_bool(_layer.make_permanent(four, _deck, DeckEdit.Kind.COLD_SEAL)).is_true()
	assert_str(_layer.apply_to(_deck.card(four)).short_name()).is_equal("10H")
	_layer.end_hand()
	assert_str(_deck.card(nine).short_name()).is_equal("10H")
	assert_str(_deck.card(four).short_name()).is_equal("4D")
	assert_int(_deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(1)


func test_an_earlier_tape_follows_its_card_through_a_switch_for_the_hand() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_layer.tape(_id_of("9H"))
	_layer.end_hand()
	_switch("9H", "4D")
	assert_bool(_layer.is_taped(_id_of("4D"))).is_true()
	assert_bool(_layer.is_taped(_id_of("9H"))).is_false()
	assert_bool(_layer.has_hand_change(_id_of("4D"))).is_false()
	_layer.end_hand()
	assert_str(_reads("9H")).is_equal("10H")
	assert_bool(_layer.is_taped(_id_of("9H"))).is_true()
	assert_bool(_layer.is_taped(_id_of("4D"))).is_false()


func test_a_nudge_is_kept_on_its_own_card_across_two_switches() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_switch("9H", "4D")
	_switch("4D", "KS")
	assert_bool(_layer.has_hand_change(_id_of("4D"))).is_false()
	assert_bool(_layer.tape(_id_of("KS"))).is_true()
	_layer.end_hand()
	assert_str(_reads("9H")).is_equal("10H")
	assert_str(_reads("4D")).is_equal("4D")
	assert_str(_reads("KS")).is_equal("KS")


func test_a_nudge_switched_away_and_back_is_kept_where_it_was_made() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_switch("9H", "4D")
	_switch("9H", "4D")
	assert_bool(_layer.tape(_id_of("9H"))).is_true()
	assert_bool(_layer.is_taped(_id_of("9H"))).is_true()
	_layer.end_hand()
	assert_str(_reads("9H")).is_equal("10H")
