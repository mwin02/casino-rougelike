extends GdUnitTestSuite
## Bots play by the rules at their table (block 17): the blackjack strategy,
## baccarat odds and High or Low calls all read the table's house rule, and
## the side-bet bots place nothing where no side bets are taken.

var _fixture: TableSessionFixture


func before_test() -> void:
	_fixture = TableSessionFixture.new()


func _sit(game: GameKind.Kind, rule: String, codes: Array[String]) -> TableSession:
	_fixture.house_rule = rule
	return _fixture.sit(game, codes)


func _cards(codes: Array[String]) -> Array[Card]:
	var cards: Array[Card] = []
	for code: String in codes:
		cards.append(Card.parse(code))
	return cards


## The strategy's play on a hard 20 against a dealer 10 with an unknown hole.
func _play_on_hard_20(rule: String) -> BlackjackEv.Play:
	var session: TableSession = _sit(GameKind.Kind.BLACKJACK, rule, ["10", "10", "10", "7"])
	var bot: StraightFlatBot = StraightFlatBot.new()
	# The table's config is the base one: the bot must look the rule up.
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var odds: Array[float] = bot.strategy.deck_odds()
	return bot.strategy.decide(_cards(["10", "10"]), Card.parse("10"), odds, false, false)


func test_a_session_gives_its_rules_config() -> void:
	var plain: TableSession = _sit(GameKind.Kind.BLACKJACK, "", ["10", "10", "10", "7"])
	assert_object(plain.rules_config()).is_same(_fixture.config)
	var ruled: TableSession = _sit(GameKind.Kind.BLACKJACK, "bust_23", ["10", "10", "10", "7"])
	assert_array(ruled.rules_config().applied_house_rules()).is_equal(["bust_23"])


func test_the_blackjack_strategy_knows_a_bust_23_table() -> void:
	var session: TableSession = _sit(GameKind.Kind.BLACKJACK, "bust_23", ["10", "10", "10", "7"])
	var bot: StraightFlatBot = StraightFlatBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	# The bust column sits one past the best live total: 22 at bust 23.
	assert_int(bot.strategy.bust_index()).is_equal(23)
	var plain: TableSession = _sit(GameKind.Kind.BLACKJACK, "", ["10", "10", "10", "7"])
	bot.begin_session(plain, _fixture.config, Deck.standard(0))
	assert_int(bot.strategy.bust_index()).is_equal(22)


func test_the_strategy_stands_on_20_at_either_table() -> void:
	assert_int(_play_on_hard_20("")).is_equal(BlackjackEv.Play.STAND)
	assert_int(_play_on_hard_20("bust_23")).is_equal(BlackjackEv.Play.STAND)


func test_the_strategy_hits_a_hard_16_harder_at_bust_23() -> void:
	# Hitting 16 busts on a 6 or more at 22, only on a 7 or more at 23.
	var values: Array[float] = []
	for rule: String in ["", "bust_23"]:
		var session: TableSession = _sit(GameKind.Kind.BLACKJACK, rule, ["10", "10", "6", "7"])
		var bot: StraightFlatBot = StraightFlatBot.new()
		bot.begin_session(session, _fixture.config, Deck.standard(0))
		var plays: Dictionary[BlackjackEv.Play, float] = bot.strategy.play_values(
			_cards(["10", "6"]), Card.parse("10"), bot.strategy.deck_odds(), false, false
		)
		values.append(plays[BlackjackEv.Play.HIT])
	assert_float(values[1]).is_greater(values[0])


func test_baccarat_bots_read_the_nine_only_natural() -> void:
	# Player 8 against banker 3 showing two cards each: settled at 8, live at 9.
	var session: TableSession = _sit(GameKind.Kind.BACCARAT, "nine_only", ["8", "3", "K", "K", "5"])
	var odds: Array[float] = BaccaratOdds.value_odds(Deck.standard(0).cards())
	var natural_min: int = BaccaratRules.from_config(session.rules_config()).natural_min
	var outcomes: Array[float] = BaccaratOdds.outcomes([8, 0], [3, 0], odds, natural_min)
	assert_float(outcomes[BaccaratOdds.PLAYER]).is_less(1.0)
	var bot: HonestAdjusterBot = HonestAdjusterBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	assert_int(bot._baccarat_rules.natural_min).is_equal(9)
	var reckless: ManipulateMaxBot = ManipulateMaxBot.new()
	reckless.begin_session(session, _fixture.config, Deck.standard(0))
	assert_int(reckless._baccarat_rules.natural_min).is_equal(9)
	bot.play_hand(session, session.start_hand(TableSessionFixture.BET))
	assert_bool(session.current_round().is_resolved()).is_true()


func test_a_reveal_bot_calls_by_the_tables_order() -> void:
	# King up, ace next: lower without the rule, higher with aces high.
	for case: Array in [["", HighLowRound.Outcome.BANKED], ["aces_high", HighLowRound.Outcome.BANKED]]:
		var rule: String = case[0]
		var session: TableSession = _sit(GameKind.Kind.HIGH_LOW, rule, ["K", "A", "K", "K"])
		var bot: RevealBot = RevealBot.new("reveal_only", false)
		bot.begin_session(session, _fixture.config, Deck.standard(0))
		bot.play_hand(session, session.start_hand(TableSessionFixture.BET))
		var rnd: HighLowRound = session.current_round()
		assert_int(rnd.outcome).is_not_equal(HighLowRound.Outcome.LOST)
		assert_int(session.finish_hand().net).is_greater(0)


func test_manipulate_max_calls_by_the_tables_order() -> void:
	var session: TableSession = _sit(GameKind.Kind.HIGH_LOW, "aces_high", ["K", "A", "K", "K"])
	var bot: ManipulateMaxBot = ManipulateMaxBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	bot.play_hand(session, session.start_hand(bot.opening_bet(session)))
	assert_int(session.finish_hand().net).is_greater(0)


func test_side_bet_bots_place_nothing_where_none_are_taken() -> void:
	var session: TableSession = _sit(
		GameKind.Kind.BLACKJACK, "no_side_bets", ["7H", "10", "7D", "9", "K", "K"]
	)
	var bots: Array[Bot] = [SideGamblerBot.new(), SideChaserBot.new(), StackerBot.new()]
	for bot: Bot in bots:
		bot.begin_session(session, _fixture.config, Deck.standard(0))
		var bets: Array[SideBet] = bot.side_bets(session)
		assert_array(bets).is_empty()
		assert_bool(session.can_start_hand(bot.opening_bet(session), bets)).is_true()
