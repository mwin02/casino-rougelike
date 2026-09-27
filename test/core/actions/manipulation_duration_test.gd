extends GdUnitTestSuite
## How long a manipulation lasts (spec §2.3): the hand, unless Masking Tape
## keeps it for the table session, or a Cold Seal or Permanent Ink charge
## writes it into the deck. Only those two edit the deck. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()
	_f.kit.masking_tape = 1
	_f.kit.cold_seals = 1
	_f.kit.ink_charges = 1


## Nudges the hole card (id 3, a 7) up to 8 and returns the actions.
func _nudged() -> HandActions:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7H", "5"])
	var actions: HandActions = _f.actions(rnd)
	actions.nudge(3, 1)
	return actions


func _hole_rank_next_hand() -> int:
	return _f.next_blackjack().dealer_hand.cards[1].rank


func test_a_change_lasts_the_hand() -> void:
	_nudged().finish()
	assert_int(_hole_rank_next_hand()).is_equal(7)
	assert_array(_f.new_edits()).is_empty()


func test_masking_tape_keeps_it_for_the_session() -> void:
	var actions: HandActions = _nudged()
	assert_bool(actions.tape(3)).is_true()
	actions.finish()
	assert_int(_hole_rank_next_hand()).is_equal(8)
	assert_bool(_f.layer.is_taped(3)).is_true()
	assert_array(_f.new_edits()).is_empty()
	assert_int(_f.kit.masking_tape).is_equal(0)
	_f.layer.end_session()
	assert_int(_hole_rank_next_hand()).is_equal(7)


func test_cold_seal_edits_the_deck() -> void:
	var actions: HandActions = _nudged()
	assert_bool(actions.seal(3)).is_true()
	actions.finish()
	assert_int(_f.deck.card(3).rank).is_equal(8)
	assert_int(_f.deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(1)
	assert_int(_f.kit.cold_seals).is_equal(0)
	_f.layer.end_session()
	assert_int(_hole_rank_next_hand()).is_equal(8)


func test_an_ink_charge_edits_the_deck() -> void:
	var actions: HandActions = _nudged()
	assert_bool(actions.ink(3)).is_true()
	assert_int(_f.deck.card(3).rank).is_equal(8)
	assert_int(_f.deck.edit_count(DeckEdit.Kind.PERMANENT_INK)).is_equal(1)
	assert_int(_f.kit.ink_charges).is_equal(0)


func test_a_sealed_switch_is_two_edits() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7H", "5"])
	var actions: HandActions = _f.actions(rnd)
	actions.switch_cards(3, 0)
	assert_bool(actions.seal(0)).is_true()
	assert_int(_f.deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(2)
	assert_str(_f.deck.card(0).short_name()).is_equal("7H")
	assert_str(_f.deck.card(3).short_name()).is_equal("10S")


func test_needs_a_consumable_left() -> void:
	_f.kit.masking_tape = 0
	_f.kit.cold_seals = 0
	_f.kit.ink_charges = 0
	var actions: HandActions = _nudged()
	assert_bool(actions.tape(3)).is_false()
	assert_bool(actions.seal(3)).is_false()
	assert_bool(actions.ink(3)).is_false()
	assert_array(_f.new_edits()).is_empty()


func test_needs_a_change_made_this_hand() -> void:
	var actions: HandActions = _nudged()
	assert_bool(actions.tape(0)).is_false()
	assert_int(_f.kit.masking_tape).is_equal(1)
	actions.finish()
	assert_bool(actions.seal(3)).is_false()
	assert_int(_f.kit.cold_seals).is_equal(1)


func test_knowledge_never_edits_the_deck() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7H", "5"])
	var actions: HandActions = _f.actions(rnd)
	actions.full_reveal(3)
	actions.look_ahead()
	actions.finish()
	assert_array(_f.new_edits()).is_empty()


func test_keepable_cards_are_those_changed_this_hand() -> void:
	var actions: HandActions = _f.actions(_f.blackjack(["10", "9", "6", "7H", "5"]))
	assert_array(actions.keepable_cards()).is_empty()
	actions.nudge(3, 1)
	assert_array(ActionsFixture.ids(actions.keepable_cards())).contains_exactly([3])


func test_a_kept_card_is_no_longer_keepable() -> void:
	var actions: HandActions = _nudged()
	actions.tape(3)
	assert_array(actions.keepable_cards()).is_empty()


func test_one_consumable_keeps_both_cards_of_a_switch() -> void:
	var actions: HandActions = _f.actions(_f.blackjack(["10", "9", "6", "7H", "5"]))
	actions.switch_cards(0, 3)
	assert_array(ActionsFixture.ids(actions.keepable_cards())).contains_exactly([0, 3])
	actions.seal(3)
	assert_array(actions.keepable_cards()).is_empty()


func test_a_high_low_card_changed_this_chain_stays_keepable_after_leaving_play() -> void:
	var rnd: HighLowRound = _f.high_low(["7S", "9H", "2C", "KD"])
	var actions: HandActions = _f.actions(rnd)
	actions.nudge(1, 1)
	rnd.proceed()
	rnd.proceed()
	rnd.call_next(HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	rnd.proceed()
	rnd.call_next(HighLowRound.Direction.LOWER)
	assert_array(ActionsFixture.ids(rnd.cards_in_play())).not_contains([1])
	assert_array(ActionsFixture.ids(actions.keepable_cards())).contains_exactly([1])
	assert_bool(actions.tape(1)).is_true()
