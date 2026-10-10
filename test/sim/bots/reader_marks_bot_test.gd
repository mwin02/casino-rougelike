extends GdUnitTestSuite
## The Reader that also marks (spec §10, §12): marks as a supplement to a
## build. It marks a face-up ten or ace while a mark is cheap, and reads a
## marked hole card from the deck instead of paying for the question.

## Player 10 + 7, dealer 9 up with a king in the hole, then filler.
const BLACKJACK: Array[String] = ["10S", "9H", "7C", "KD", "5S", "4H", "3C", "2D"]
## Player 10 + 10, dealer ace up, 7 in the hole: three cards worth a mark.
const THREE_TO_MARK: Array[String] = ["10S", "AC", "10H", "7D", "4S", "3H", "2C", "6D"]


class Seat:
	var bot: ReaderMarksBot = ReaderMarksBot.new()
	var session: TableSession
	var deck: Deck
	var fixture: TableSessionFixture = TableSessionFixture.new()

	func hand() -> Array[ActionKind.Kind]:
		var actions: HandActions = session.start_hand(
			bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
		)
		bot.play_hand(session, actions)
		session.finish_hand()
		var result: Array[ActionKind.Kind] = []
		for use: ActionUse in actions.used:
			result.append(use.action)
		return result


func _seat(stakes: TableStakes.Kind, codes: Array[String]) -> Seat:
	var seat: Seat = Seat.new()
	seat.fixture.stakes = stakes
	seat.session = seat.fixture.sit(GameKind.Kind.BLACKJACK, codes)
	seat.deck = seat.fixture.deck
	seat.bot.kit = seat.fixture.kit
	seat.bot.begin_session(seat.session, seat.fixture.config, seat.deck)
	return seat


func test_it_marks_a_face_up_ten_while_the_mark_is_cheap() -> void:
	var seat: Seat = _seat(TableStakes.Kind.LOW, BLACKJACK)
	assert_array(seat.hand()).contains_exactly([ActionKind.Kind.MARK])
	assert_bool(seat.deck.card(0).is_marked()).is_true()
	# The 9 and the 7 showing are not worth a symbol.
	assert_bool(seat.deck.card(1).is_marked()).is_false()
	assert_bool(seat.deck.card(2).is_marked()).is_false()


## §4.3: each mark in a session costs more than the last.
func test_it_does_not_mark_above_its_cost_cap() -> void:
	var seat: Seat = _seat(TableStakes.Kind.LOW, THREE_TO_MARK)
	assert_array(seat.hand()).contains_exactly([ActionKind.Kind.MARK])
	assert_int(seat.deck.marked_count()).is_equal(1)
	assert_array(seat.hand()).is_empty()
	assert_int(seat.deck.marked_count()).is_equal(1)


func test_tens_and_aces_carry_different_symbols() -> void:
	var seat: Seat = _seat(TableStakes.Kind.LOW, THREE_TO_MARK)
	assert_int(ReaderMarksBot.symbol_for(seat.bot.kit, seat.deck.card(0))).is_not_equal(
		ReaderMarksBot.symbol_for(seat.bot.kit, seat.deck.card(1))
	)
	assert_int(ReaderMarksBot.symbol_for(seat.bot.kit, seat.deck.card(3))).is_equal(
		Card.NO_SYMBOL
	)


func test_it_still_asks_about_an_unmarked_hole_card() -> void:
	var seat: Seat = _seat(TableStakes.Kind.HIGH, BLACKJACK)
	assert_array(seat.hand()).contains_exactly(
		[ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.MARK]
	)


func test_a_marked_hole_card_needs_no_question() -> void:
	var seat: Seat = _seat(TableStakes.Kind.HIGH, BLACKJACK)
	# The king in the hole and the ten already carry the tens' symbol.
	var tens: int = ReaderMarksBot.symbol_for(seat.bot.kit, seat.deck.card(3))
	seat.deck.mark(3, tens)
	seat.deck.mark(0, tens)
	assert_array(seat.hand()).not_contains([ActionKind.Kind.PARTIAL_REVEAL])


func test_a_marked_hole_card_is_read_from_the_deck() -> void:
	var seat: Seat = _seat(TableStakes.Kind.HIGH, BLACKJACK)
	seat.deck.mark(3, 0)
	seat.deck.mark(0, 0)
	seat.session.start_hand(seat.bot.opening_bet(seat.session), BaccaratRound.BetSide.BANKER, [])
	var rnd: BlackjackRound = seat.session.current_round()
	assert_float(seat.bot.hole_odds(rnd)[10]).is_equal_approx(1.0, 0.0001)


## With marks in the deck, an unmarked hole card is one of the unmarked cards.
func test_an_unmarked_hole_card_is_none_of_the_marked_ones() -> void:
	var seat: Seat = _seat(TableStakes.Kind.LOW, BLACKJACK)
	seat.deck.mark(0, 0)
	seat.session.start_hand(seat.bot.opening_bet(seat.session), BaccaratRound.BetSide.BANKER, [])
	var rnd: BlackjackRound = seat.session.current_round()
	# Seven unmarked cards, one of them (the king) ten-value.
	assert_float(seat.bot.hole_odds(rnd)[10]).is_equal_approx(1.0 / 7.0, 0.0001)


## Poker Face makes a first-window mark free; the heat floor still isn't.
func test_a_free_mark_is_still_one_a_session() -> void:
	var seat: Seat = _seat(TableStakes.Kind.LOW, THREE_TO_MARK)
	seat.fixture.kit.poker_face = true
	assert_array(seat.hand()).contains_exactly([ActionKind.Kind.MARK])
	assert_array(seat.hand()).is_empty()
	assert_int(seat.deck.marked_count()).is_equal(1)


## Every ten in the deck is marked, so an unmarked hole card is no ten.
func test_the_marks_can_answer_for_an_unmarked_hole_card() -> void:
	var codes: Array[String] = ["10S", "9H", "7C", "5D", "6S", "4H", "3C", "2D"]
	var seat: Seat = _seat(TableStakes.Kind.HIGH, codes)
	seat.deck.mark(0, ReaderMarksBot.symbol_for(seat.bot.kit, seat.deck.card(0)))
	assert_array(seat.hand()).not_contains([ActionKind.Kind.PARTIAL_REVEAL])


## §7.2: house cards carry no marks and can't take one.
func test_a_house_deck_ends_the_marks_use() -> void:
	var seat: Seat = _seat(TableStakes.Kind.HIGH, BLACKJACK)
	seat.deck.mark(0, 0)
	seat.session._house_deck = Deck.standard(0, TableSession.HOUSE_ID_BASE)
	var actions: Array[ActionKind.Kind] = seat.hand()
	assert_array(actions).not_contains([ActionKind.Kind.MARK])
	assert_int(seat.deck.marked_count()).is_equal(1)


func test_a_house_deck_hole_card_is_read_as_the_reader_reads_it() -> void:
	var seat: Seat = _seat(TableStakes.Kind.HIGH, BLACKJACK)
	seat.deck.mark(0, 0)
	seat.session._house_deck = Deck.standard(0, TableSession.HOUSE_ID_BASE)
	seat.session.start_hand(seat.bot.opening_bet(seat.session), BaccaratRound.BetSide.BANKER, [])
	var rnd: BlackjackRound = seat.session.current_round()
	assert_array(seat.bot.hole_odds(rnd)).is_equal(seat.bot.strategy.deck_odds())


func test_it_runs_only_when_named() -> void:
	assert_array(BotRoster.names()).contains(["reader_marks"])
	assert_array(BotRoster.default_names()).not_contains(["reader_marks"])
