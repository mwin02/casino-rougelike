extends GdUnitTestSuite
## Manipulation changes last the hand. Masking Tape keeps one for the session;
## Cold Seal and Permanent Ink write it into the deck (spec §2.3).

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


func _dealt_composition() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for card: Card in _deck.dealing_cards(_layer):
		counts[card.short_name()] = counts.get(card.short_name(), 0) + 1
	return counts


## A hand's worth of manipulation: nudge, recolour, switch, palm.
func _manipulate() -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS)
	_layer.change(_id_of("2C"), 2, Card.Suit.DIAMONDS)
	_layer.switch_cards(_deck.card(_id_of("KS")), _deck.card(_id_of("4D")))
	_layer.change(_id_of("3H"), 1, Card.Suit.SPADES)


func test_changes_apply_during_the_hand() -> void:
	_manipulate()
	assert_str(_reads("9H")).is_equal("10H")
	assert_str(_reads("2C")).is_equal("2D")
	assert_str(_reads("KS")).is_equal("4D")
	assert_str(_reads("4D")).is_equal("KS")
	assert_str(_reads("3H")).is_equal("AS")


func test_every_change_reverts_at_end_of_hand() -> void:
	var standard: Dictionary[String, int] = Deck.standard(MIN_SIZE).composition()
	_manipulate()
	_layer.end_hand()
	assert_int(_layer.size()).is_equal(0)
	assert_dict(_dealt_composition()).is_equal(standard)
	assert_dict(_deck.composition()).is_equal(standard)


func test_changes_never_touch_the_owned_deck() -> void:
	_manipulate()
	assert_str(_deck.card(_id_of("9H")).short_name()).is_equal("9H")
	assert_int(_deck.edits().size()).is_equal(0)


func test_tape_lasts_the_session_then_reverts() -> void:
	_manipulate()
	assert_bool(_layer.tape(_id_of("3H"))).is_true()
	_layer.end_hand()
	_layer.end_hand()
	assert_str(_reads("3H")).is_equal("AS")
	assert_str(_reads("9H")).is_equal("9H")
	assert_int(_deck.edits().size()).is_equal(0)
	_layer.end_session()
	assert_str(_reads("3H")).is_equal("3H")
	assert_dict(_dealt_composition()).is_equal(Deck.standard(MIN_SIZE).composition())


func test_tape_needs_a_change_this_hand() -> void:
	assert_bool(_layer.tape(_id_of("3H"))).is_false()
	_layer.change(_id_of("3H"), 1, Card.Suit.SPADES)
	_layer.end_hand()
	assert_bool(_layer.tape(_id_of("3H"))).is_false()


func test_tape_on_a_switch_covers_both_cards() -> void:
	_manipulate()
	_layer.tape(_id_of("KS"))
	_layer.end_hand()
	assert_str(_reads("KS")).is_equal("4D")
	assert_str(_reads("4D")).is_equal("KS")


# gdlint: ignore=unused-argument
func test_make_permanent_edits_the_deck(source: DeckEdit.Kind, test_parameters: Array = [
	[DeckEdit.Kind.COLD_SEAL],
	[DeckEdit.Kind.PERMANENT_INK],
]) -> void:
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS)
	assert_bool(_layer.make_permanent(id, _deck, source)).is_true()
	_layer.end_session()
	assert_str(_deck.card(id).short_name()).is_equal("10H")
	assert_int(_deck.edit_count(source)).is_equal(1)
	assert_int(_layer.size()).is_equal(0)


func test_make_permanent_on_a_switch_seals_both_cards() -> void:
	var king: int = _id_of("KS")
	var four: int = _id_of("4D")
	_layer.switch_cards(_deck.card(king), _deck.card(four))
	_layer.make_permanent(king, _deck, DeckEdit.Kind.COLD_SEAL)
	assert_str(_deck.card(king).short_name()).is_equal("4D")
	assert_str(_deck.card(four).short_name()).is_equal("KS")
	assert_int(_deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(2)


func test_make_permanent_needs_a_change_this_hand() -> void:
	var id: int = _id_of("9H")
	assert_bool(_layer.make_permanent(id, _deck, DeckEdit.Kind.COLD_SEAL)).is_false()
	_layer.change(id, 10, Card.Suit.HEARTS)
	_layer.end_hand()
	assert_bool(_layer.make_permanent(id, _deck, DeckEdit.Kind.COLD_SEAL)).is_false()
	assert_int(_deck.edits().size()).is_equal(0)


func test_make_permanent_replaces_a_taped_change() -> void:
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS)
	_layer.tape(id)
	_layer.end_hand()
	_layer.change(id, 11, Card.Suit.HEARTS)
	_layer.make_permanent(id, _deck, DeckEdit.Kind.COLD_SEAL)
	_layer.end_session()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("JH")
	assert_int(_layer.size()).is_equal(0)


func test_make_permanent_fails_for_a_card_outside_the_deck() -> void:
	var outsider: Card = Card.new(9, Card.Suit.HEARTS)
	outsider.id = 999
	_layer.change(outsider.id, 10, Card.Suit.HEARTS)
	assert_bool(_layer.make_permanent(outsider.id, _deck, DeckEdit.Kind.COLD_SEAL)).is_false()
	assert_int(_deck.edits().size()).is_equal(0)
	assert_int(_layer.size()).is_equal(1)


func test_switch_trades_identities_and_marks_stay_on_the_card() -> void:
	# Spec §2.3: composition is unchanged, marks now sit on the other ranks.
	var king: int = _id_of("KS")
	_deck.mark(king, 0)
	_layer.switch_cards(_deck.card(king), _deck.card(_id_of("4D")))
	var switched_king: Card = _layer.apply_to(_deck.card(king))
	assert_str(switched_king.short_name()).is_equal("4D")
	assert_int(switched_king.symbol).is_equal(0)
	assert_dict(_dealt_composition()).is_equal(_deck.composition())


func test_hand_change_reverts_to_the_taped_change_beneath_it() -> void:
	# A taped Palm, then a Nudge on the same card next hand: the Palm survives.
	var id: int = _id_of("3H")
	_layer.change(id, 1, Card.Suit.SPADES)
	_layer.tape(id)
	_layer.end_hand()
	_layer.change(id, 2, Card.Suit.SPADES)
	assert_str(_reads("3H")).is_equal("2S")
	assert_int(_layer.size()).is_equal(1)
	_layer.end_hand()
	assert_str(_reads("3H")).is_equal("AS")


func test_is_taped_tracks_what_the_card_shows() -> void:
	var id: int = _id_of("3H")
	_layer.change(id, 1, Card.Suit.SPADES)
	assert_bool(_layer.is_taped(id)).is_false()
	_layer.tape(id)
	assert_bool(_layer.is_taped(id)).is_true()
	_layer.end_hand()
	_layer.change(id, 2, Card.Suit.SPADES)
	assert_bool(_layer.is_taped(id)).is_false()
	_layer.end_hand()
	assert_bool(_layer.is_taped(id)).is_true()
	_layer.end_session()
	assert_bool(_layer.is_taped(id)).is_false()


func test_bad_rank_is_ignored() -> void:
	_layer.change(_id_of("KS"), 14, Card.Suit.SPADES)
	assert_int(_layer.size()).is_equal(0)
