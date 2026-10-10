extends GdUnitTestSuite
## The archetype bots (spec §10, §12): the Reader, the Whale, the Marker
## and the Mechanic. The Stacker has its own suite.

## Blackjack: player 10 + 7, dealer 9 up with a 10 in the hole, then filler.
const BLACKJACK: Array[String] = ["10S", "9H", "7C", "KD", "5S", "4H", "3C", "2D"]

## Player 10 + 7 against dealer 10 up, 9 in the hole: a losing 17 to rescue.
const LOSING: Array[String] = ["10S", "10C", "7H", "9D", "KS", "KH", "KD", "KC"]


## A Marker seated at blackjack.
class Seat:
	var bot: MarkerBot = MarkerBot.new()
	var session: TableSession
	var deck: Deck


func _sit(stakes: TableStakes.Kind, game: GameKind.Kind, codes: Array[String]) -> TableSession:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.stakes = stakes
	return fixture.sit(game, codes)


## Plays one hand at the bot's opening bet, to resolution but not settled;
## returns its actions.
func _play(bot: Bot, session: TableSession) -> HandActions:
	bot.begin_session(session, TuneConfig.load_default(), Deck.standard(0))
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	return hand


func _actions(hand: HandActions) -> Array[ActionKind.Kind]:
	var result: Array[ActionKind.Kind] = []
	for use: ActionUse in hand.used:
		result.append(use.action)
	return result


func test_the_reader_never_acts_at_low_stakes() -> void:
	var session: TableSession = _sit(TableStakes.Kind.LOW, GameKind.Kind.BLACKJACK, BLACKJACK)
	var hand: HandActions = _play(ReaderBot.new(), session)
	assert_array(_actions(hand)).is_empty()


func test_the_reader_asks_a_partial_question_at_blackjack() -> void:
	var session: TableSession = _sit(TableStakes.Kind.HIGH, GameKind.Kind.BLACKJACK, BLACKJACK)
	var hand: HandActions = _play(ReaderBot.new(), session)
	assert_array(_actions(hand)).contains_exactly([ActionKind.Kind.PARTIAL_REVEAL])


func test_the_reader_full_reveals_at_baccarat_and_high_or_low() -> void:
	for game: GameKind.Kind in [GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW]:
		var session: TableSession = _sit(TableStakes.Kind.HIGH, game, BLACKJACK)
		var hand: HandActions = _play(ReaderBot.new(), session)
		assert_array(_actions(hand)).contains_exactly([ActionKind.Kind.FULL_REVEAL])


## §7.1: reads cost double once the table is Marked; the reader waits.
func test_the_reader_stops_reading_once_marked() -> void:
	var session: TableSession = _sit(TableStakes.Kind.HIGH, GameKind.Kind.BLACKJACK, BLACKJACK)
	session.table_heat.heat = TuneConfig.load_default().get_float_list("tiers", "thresholds")[1]
	var hand: HandActions = _play(ReaderBot.new(), session)
	assert_array(_actions(hand)).is_empty()


## §7.1: a read and the raise it sets up, at the table's heat, would reach
## Backed off. The Reader plays the hand honestly and stands up.
func test_the_reader_never_reads_into_a_back_off() -> void:
	var session: TableSession = _sit(TableStakes.Kind.HIGH, GameKind.Kind.HIGH_LOW, BLACKJACK)
	session.table_heat.heat = 80.0
	var bot: ReaderBot = ReaderBot.new()
	var hand: HandActions = _play(bot, session)
	assert_array(_actions(hand)).is_empty()
	assert_bool(bot.wants_to_stand(session)).is_true()


func test_the_reader_reads_while_a_back_off_is_out_of_reach() -> void:
	var session: TableSession = _sit(TableStakes.Kind.HIGH, GameKind.Kind.HIGH_LOW, BLACKJACK)
	session.table_heat.heat = 40.0
	var bot: ReaderBot = ReaderBot.new()
	var hand: HandActions = _play(bot, session)
	assert_array(_actions(hand)).contains_exactly([ActionKind.Kind.FULL_REVEAL])
	assert_bool(bot.wants_to_stand(session)).is_false()


func test_a_ten_card_answer_narrows_the_hole_card() -> void:
	var odds: Array[float] = [0.0, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
	var ten: Array[float] = ReaderBot.narrow(odds, true)
	var not_ten: Array[float] = ReaderBot.narrow(odds, false)
	assert_float(ten[10]).is_equal_approx(1.0, 0.0001)
	assert_float(not_ten[10]).is_equal(0.0)
	assert_float(not_ten[1]).is_equal_approx(1.0 / 9.0, 0.0001)


func test_the_whale_opens_at_the_table_max() -> void:
	var session: TableSession = _sit(TableStakes.Kind.HIGH, GameKind.Kind.BLACKJACK, BLACKJACK)
	assert_int(WhaleBot.new().opening_bet(session)).is_equal(TableSessionFixture.TABLE_MAX)
	session.bankroll = TableSessionFixture.TABLE_MAX - 1
	assert_int(WhaleBot.new().opening_bet(session)).is_equal(TableSessionFixture.TABLE_MAX - 1)


## The Whale never changes the bet (§10: the multiplier stays ×1).
func test_the_whale_never_adjusts() -> void:
	for game: GameKind.Kind in [
		GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW
	]:
		var session: TableSession = _sit(TableStakes.Kind.HIGH, game, BLACKJACK)
		var hand: HandActions = _play(WhaleBot.new(), session)
		assert_array(_actions(hand)).contains_exactly([ActionKind.Kind.FULL_REVEAL])
		var rnd: GameRound = session.current_round()
		assert_int(rnd.total_bet()).is_equal(rnd.opening_bet)


func test_both_are_in_the_default_roster() -> void:
	assert_array(BotRoster.default_names()).contains(
		["reader", "whale", "marker", "mechanic", "stacker"]
	)


# The Marker

func _marker_at(stakes: TableStakes.Kind, codes: Array[String] = BLACKJACK) -> Seat:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.stakes = stakes
	var seat: Seat = Seat.new()
	seat.session = fixture.sit(GameKind.Kind.BLACKJACK, codes)
	seat.deck = fixture.deck
	seat.bot.kit = fixture.kit
	seat.bot.begin_session(seat.session, fixture.config, fixture.deck)
	return seat


func _hand(bot: Bot, session: TableSession) -> HandActions:
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	return hand


func test_the_marker_marks_face_up_tens_and_aces_at_low_stakes() -> void:
	# Player A + 5, dealer 10 up, 7 in the hole.
	var codes: Array[String] = ["AS", "10C", "5H", "7D", "4S", "3H", "2C", "6D"]
	var seat: Seat = _marker_at(TableStakes.Kind.LOW, codes)
	var deck: Deck = seat.deck
	var actions: Array[ActionKind.Kind] = _actions(_hand(seat.bot, seat.session))
	assert_array(actions).is_not_empty()
	for action: ActionKind.Kind in actions:
		assert_int(action).is_equal(ActionKind.Kind.MARK)
	# The ace and the ten showing carry different symbols; the 5 none.
	assert_bool(deck.card(0).is_marked()).is_true()
	assert_bool(deck.card(1).is_marked()).is_true()
	assert_int(deck.card(0).symbol).is_not_equal(deck.card(1).symbol)
	assert_bool(deck.card(2).is_marked()).is_false()


func test_the_marker_never_marks_at_high_stakes() -> void:
	var seat: Seat = _marker_at(TableStakes.Kind.HIGH)
	assert_array(_actions(_hand(seat.bot, seat.session))).is_empty()


func test_the_marker_stops_at_its_target() -> void:
	var codes: Array[String] = TableSessionFixture.repeat("KS", MarkerBot.MARK_TARGET + 4)
	var seat: Seat = _marker_at(TableStakes.Kind.LOW, codes)
	for id: int in MarkerBot.MARK_TARGET:
		seat.deck.mark(id, 0)
	assert_array(_actions(_hand(seat.bot, seat.session))).is_empty()


## §4.3: a mark shows on a face-down card; the deck says what it can be.
func test_a_marked_hole_card_is_read_from_the_deck() -> void:
	var seat: Seat = _marker_at(TableStakes.Kind.HIGH)
	seat.deck.mark(3, 0)
	seat.deck.mark(0, 0)
	seat.session.start_hand(seat.bot.opening_bet(seat.session), BaccaratRound.BetSide.BANKER, [])
	var rnd: BlackjackRound = seat.session.current_round()
	rnd.dealer_hand.cards[1].symbol = 0
	# Both cards carrying symbol 0 are ten-value.
	assert_float(seat.bot.hole_odds(rnd)[10]).is_equal_approx(1.0, 0.0001)


func test_the_marker_plays_only_blackjack() -> void:
	var bot: MarkerBot = MarkerBot.new()
	assert_bool(bot.plays(GameKind.Kind.BLACKJACK)).is_true()
	assert_bool(bot.plays(GameKind.Kind.BACCARAT)).is_false()
	assert_bool(bot.plays(GameKind.Kind.HIGH_LOW)).is_false()


func _node(stakes: TableStakes.Kind, game: GameKind.Kind) -> MapNode:
	var node: MapNode = MapNode.new(1, 0, MapNode.Kind.TABLES)
	node.stakes = stakes
	node.tables.append(Table.new(game, stakes, 1, 1000, 4000))
	return node


## Setup at low stakes until the deck holds its marks, then payoff (§5.1).
func test_the_markers_route_sets_up_then_cashes_in() -> void:
	var plan: RunPlan = MarkerBot.new().run_plan()
	var high: MapNode = _node(TableStakes.Kind.HIGH, GameKind.Kind.BLACKJACK)
	var low: MapNode = _node(TableStakes.Kind.LOW, GameKind.Kind.BLACKJACK)
	var other: MapNode = _node(TableStakes.Kind.LOW, GameKind.Kind.BACCARAT)
	var deck: Deck = Deck.standard(0)
	assert_object(plan.route([other, high, low], 100_000, deck)).is_same(low)
	for id: int in MarkerBot.MARK_TARGET:
		deck.mark(id, 0)
	assert_object(plan.route([other, low, high], 100_000, deck)).is_same(high)


# The Mechanic

func test_the_mechanic_cools_after_a_rescue() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, LOSING)
	var bot: MechanicBot = MechanicBot.new()
	bot.begin_session(session, fixture.config, fixture.deck)
	assert_int(bot.opening_bet(session)).is_equal(
		(TableSessionFixture.TABLE_MIN + TableSessionFixture.TABLE_MAX) / 2
	)
	var hand: HandActions = _hand(bot, session)
	assert_bool(
		ActionKind.Kind.PALM in _actions(hand) or ActionKind.Kind.NUDGE in _actions(hand)
	).is_true()
	session.finish_hand()
	for i: int in MechanicBot.COOL_HANDS:
		assert_int(bot.opening_bet(session)).is_equal(TableSessionFixture.TABLE_MIN)
		assert_array(_actions(_hand(bot, session))).is_empty()
		session.finish_hand()
	assert_int(bot.opening_bet(session)).is_greater(TableSessionFixture.TABLE_MIN)


func test_the_mechanic_stands_up_and_presses_on() -> void:
	var bot: MechanicBot = MechanicBot.new()
	assert_bool(bot.stands_up()).is_true()
	assert_int(bot.run_plan().cash_out_pct).is_equal(RunPlan.CASH_OUT_PCT)
	assert_array(bot.run_plan().wishlist).is_not_empty()



## The Reader raises only on a clear edge; the honest adjuster on any.
func test_the_reader_raises_on_a_clear_edge() -> void:
	assert_float(ReaderBot.new().raise_above()).is_equal(ReaderBot.RAISE_ON_EDGE)
	assert_float(ReaderBot.RAISE_ON_EDGE).is_greater(HonestAdjusterBot.new().raise_above())
