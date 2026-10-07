extends GdUnitTestSuite
## Marks (spec §4.3): a symbol on a card in play, kept by the owned deck for
## the whole run, and visible whenever the card is in play, face down
## included. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func test_mark_writes_the_symbol_to_the_owned_deck() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	assert_bool(_f.actions(rnd).mark(0, 1)).is_true()
	assert_int(_f.deck.card(0).symbol).is_equal(1)


func test_mark_shows_on_the_card_in_play_now() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	var actions: HandActions = _f.actions(rnd)
	actions.mark(0, 1)
	assert_int(rnd.hands[0].cards[0].symbol).is_equal(1)
	assert_dict(actions.visible_marks()).is_equal({0: 1})


func test_mark_shows_when_the_card_enters_play_next_hand() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	_f.actions(rnd).mark(0, 1)
	var next: BlackjackRound = _f.next_blackjack()
	assert_int(next.hands[0].cards[0].symbol).is_equal(1)
	assert_dict(_f.actions(next).visible_marks()).is_equal({0: 1})


func test_a_marked_face_down_card_shows_its_symbol() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	_f.actions(rnd).mark(3, 0)
	var next: BlackjackRound = _f.next_blackjack()
	assert_dict(_f.actions(next).visible_marks()).is_equal({3: 0})


func test_a_marked_incoming_card_shows_its_symbol_in_its_window() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9"])
	_f.actions(rnd).mark(1, 0)
	var next: HighLowRound = _f.next_high_low()
	assert_dict(_f.actions(next).visible_marks()).is_equal({1: 0})


func test_remarking_overwrites_the_old_symbol() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	var actions: HandActions = _f.actions(rnd)
	actions.mark(0, 0)
	actions.mark(0, 1)
	assert_int(_f.deck.card(0).symbol).is_equal(1)


func test_only_symbols_the_kit_holds() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	var actions: HandActions = _f.actions(rnd)
	assert_bool(actions.mark(0, ItemKind.SYMBOLS[ItemKind.Kind.WAX_PENCIL])).is_false()
	assert_bool(actions.mark(0, -1)).is_false()
	assert_bool(_f.deck.card(0).is_marked()).is_false()


func test_only_cards_in_play() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7", "2"])
	assert_bool(_f.actions(rnd).mark(4, 0)).is_false()


func test_counts_marks_made_this_session() -> void:
	var rnd: BlackjackRound = _f.blackjack(["A", "9", "6", "7"])
	var actions: HandActions = _f.actions(rnd)
	actions.mark(0, 0)
	actions.mark(2, 1)
	assert_int(_f.session.marks_made).is_equal(2)
	assert_int(actions.used.size()).is_equal(2)
