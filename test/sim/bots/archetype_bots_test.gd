extends GdUnitTestSuite
## The archetype bots (spec §10, §12): the Reader and the Whale.

## Blackjack: player 10 + 7, dealer 9 up with a 10 in the hole, then filler.
const BLACKJACK: Array[String] = ["10S", "9H", "7C", "KD", "5S", "4H", "3C", "2D"]


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
	assert_array(BotRoster.default_names()).contains(["reader", "whale"])
