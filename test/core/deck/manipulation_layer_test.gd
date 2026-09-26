extends GdUnitTestSuite
## Manipulation changes last the hand or the table session, never the owned
## deck (spec §2.3).

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


func _dealt_composition() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for card: Card in _deck.dealing_cards(_layer):
		counts[card.short_name()] = counts.get(card.short_name(), 0) + 1
	return counts


## A hand's worth of manipulation: nudge, recolour, switch, palm.
func _manipulate(duration: ManipulationLayer.Duration) -> void:
	_layer.change(_id_of("9H"), 10, Card.Suit.HEARTS, duration)
	_layer.change(_id_of("2C"), 2, Card.Suit.DIAMONDS, duration)
	_layer.switch_cards(_deck.card(_id_of("KS")), _deck.card(_id_of("4D")), duration)
	_layer.change(_id_of("3H"), 1, Card.Suit.SPADES, ManipulationLayer.Duration.SESSION)


func test_hand_mode_reverts_everything_but_palm_at_end_of_hand() -> void:
	_manipulate(ManipulationLayer.Duration.HAND)
	_layer.end_hand()
	var expected: Dictionary[String, int] = Deck.standard(MIN_SIZE).composition()
	expected.erase("3H")
	expected["AS"] = 2
	assert_dict(_dealt_composition()).is_equal(expected)
	for code: String in ["9H", "2C", "KS", "4D"]:
		assert_str(_layer.apply_to(_deck.card(_id_of(code))).short_name()).is_equal(code)
	assert_int(_layer.size()).is_equal(1)


func test_palm_lasts_the_session_even_in_hand_mode() -> void:
	_manipulate(ManipulationLayer.Duration.HAND)
	_layer.end_hand()
	assert_str(_layer.apply_to(_deck.card(_id_of("3H"))).short_name()).is_equal("AS")
	_layer.end_session()
	assert_str(_layer.apply_to(_deck.card(_id_of("3H"))).short_name()).is_equal("3H")


func test_session_mode_survives_hands_and_reverts_at_session_end() -> void:
	var standard: Dictionary[String, int] = Deck.standard(MIN_SIZE).composition()
	_manipulate(ManipulationLayer.Duration.SESSION)
	_layer.end_hand()
	_layer.end_hand()
	assert_int(_dealt_composition().get("10H", 0)).is_equal(2)
	assert_int(_dealt_composition().get("2D", 0)).is_equal(2)
	assert_dict(_deck.composition()).is_equal(standard)
	_layer.end_session()
	assert_int(_layer.size()).is_equal(0)
	assert_dict(_dealt_composition()).is_equal(standard)


func test_changes_never_touch_the_owned_deck() -> void:
	_manipulate(ManipulationLayer.Duration.SESSION)
	assert_str(_deck.card(_id_of("9H")).short_name()).is_equal("9H")
	assert_int(_deck.edits().size()).is_equal(0)


func test_carried_changes_last_extra_sessions() -> void:
	# Long Con (spec §9): changes carry into the next N table sessions.
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS, ManipulationLayer.Duration.SESSION, 2)
	_layer.end_session()
	_layer.end_session()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("10H")
	_layer.end_session()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("9H")


func test_switch_trades_identities_and_marks_stay_on_the_card() -> void:
	# Spec §2.3: composition is unchanged, marks now sit on the other ranks.
	var king: int = _id_of("KS")
	var four: int = _id_of("4D")
	_deck.mark(king, 0)
	_layer.switch_cards(_deck.card(king), _deck.card(four), ManipulationLayer.Duration.SESSION)
	var switched_king: Card = _layer.apply_to(_deck.card(king))
	assert_str(switched_king.short_name()).is_equal("4D")
	assert_int(switched_king.symbol).is_equal(0)
	assert_str(_layer.apply_to(_deck.card(four)).short_name()).is_equal("KS")
	assert_dict(_dealt_composition()).is_equal(_deck.composition())


func test_hand_change_reverts_to_the_session_change_beneath_it() -> void:
	# A Palm then a hand-length Nudge on the same card: the Palm survives.
	var id: int = _id_of("3H")
	_layer.change(id, 1, Card.Suit.SPADES, ManipulationLayer.Duration.SESSION)
	_layer.change(id, 2, Card.Suit.SPADES, ManipulationLayer.Duration.HAND)
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("2S")
	assert_int(_layer.size()).is_equal(1)
	_layer.end_hand()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("AS")


func test_session_change_replaces_a_hand_change() -> void:
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS, ManipulationLayer.Duration.HAND)
	_layer.change(id, 11, Card.Suit.HEARTS, ManipulationLayer.Duration.SESSION)
	_layer.end_hand()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("JH")


func test_later_session_change_sets_the_lifetime() -> void:
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS, ManipulationLayer.Duration.SESSION, 2)
	_layer.change(id, 11, Card.Suit.HEARTS, ManipulationLayer.Duration.SESSION)
	_layer.end_session()
	assert_str(_layer.apply_to(_deck.card(id)).short_name()).is_equal("9H")


func test_bad_rank_is_ignored() -> void:
	_layer.change(_id_of("KS"), 14, Card.Suit.SPADES, ManipulationLayer.Duration.SESSION)
	assert_int(_layer.size()).is_equal(0)
