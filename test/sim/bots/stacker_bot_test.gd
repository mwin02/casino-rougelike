extends GdUnitTestSuite
## The Stacker (spec §10, §12): deck composition plus side bets, few
## windows.

## Player 7 + 8: one Nudge from a pair. Dealer 9 up, 10 in the hole.
const NEAR_PAIR: Array[String] = ["7S", "9H", "8C", "KD", "5S", "4H", "3C", "2D"]
const QUOTA: int = 140_000


func _sit() -> TableSession:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.stakes = TableStakes.Kind.HIGH
	return fixture.sit(GameKind.Kind.BLACKJACK, NEAR_PAIR)

func _services(deck: Deck, bankroll: int) -> DeckServices:
	var config: TuneConfig = TuneConfig.load_default()
	return DeckServices.new(
		DeckRules.from_config(config), deck, ActionKit.starting(),
		ShopPricing.new(QUOTA, 100, 100), bankroll, GameRng.new(1).stream(GameRng.Stream.SHOP)
	)


func _ranks(deck: Deck, ranks: Array[int]) -> int:
	var count: int = 0
	for card: Card in deck.cards():
		if card.rank in ranks:
			count += 1
	return count


func test_the_stacker_removes_the_dealers_cards() -> void:
	var deck: Deck = Deck.standard(20)
	StackerBot.new().run_plan().use_services(_services(deck, 10_000_000), deck, 0)
	assert_int(deck.size()).is_equal(52 - StackerBot.REMOVE_TARGET)
	assert_int(_ranks(deck, StackerBot.REMOVE_RANKS)).is_equal(
		4 * StackerBot.REMOVE_RANKS.size() - StackerBot.REMOVE_TARGET
	)


func test_the_stacker_keeps_what_it_holds_back() -> void:
	var deck: Deck = Deck.standard(20)
	var services: DeckServices = _services(deck, 100_000)
	var keep: int = 100_000 - services.price(DeckServices.Service.REMOVE) + 1
	StackerBot.new().run_plan().use_services(services, deck, keep)
	assert_int(deck.size()).is_equal(52)


func test_the_stacker_bets_perfect_pairs_at_the_cap() -> void:
	var session: TableSession = _sit()
	var bets: Array[SideBet] = StackerBot.new().side_bets(session)
	assert_int(bets.size()).is_equal(1)
	assert_int(bets[0].kind).is_equal(SideBetKind.Kind.PERFECT_PAIRS)
	assert_int(bets[0].stake).is_equal(session.side_bet_cap())


## Few windows: at most one Nudge a hand, to pair the player's cards.
func test_the_stacker_nudges_its_cards_into_a_pair() -> void:
	var session: TableSession = _sit()
	var bot: StackerBot = StackerBot.new()
	bot.begin_session(session, TuneConfig.load_default(), Deck.standard(0))
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	assert_int(hand.used.size()).is_equal(1)
	assert_int(hand.used[0].action).is_equal(ActionKind.Kind.NUDGE)
	var cards: Array[Card] = (session.current_round() as BlackjackRound).hands[0].cards
	assert_int(cards[0].rank).is_equal(cards[1].rank)


func test_the_stacker_plays_blackjack() -> void:
	var bot: StackerBot = StackerBot.new()
	assert_bool(bot.plays(GameKind.Kind.BLACKJACK)).is_true()
	assert_bool(bot.plays(GameKind.Kind.HIGH_LOW)).is_false()
	assert_array(bot.run_plan().games).contains_exactly([GameKind.Kind.BLACKJACK])


## Played well: no Nudge that costs more than its budget.
func test_the_stacker_skips_a_nudge_over_its_budget() -> void:
	var session: TableSession = _sit()
	var bot: StackerBot = StackerBot.new()
	bot.begin_session(session, TuneConfig.load_default(), Deck.standard(0))
	bot.nudge_budget = 1.0
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	assert_array(hand.used).is_empty()


func test_the_greedy_stacker_nudges_regardless() -> void:
	var session: TableSession = _sit()
	var bot: StackerBot = StackerBot.new(true)
	bot.begin_session(session, TuneConfig.load_default(), Deck.standard(0))
	bot.nudge_budget = 1.0
	var hand: HandActions = session.start_hand(
		bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
	)
	bot.play_hand(session, hand)
	assert_int(hand.used.size()).is_equal(1)
	assert_str(bot.bot_name()).is_equal("stacker_greedy")
	assert_bool("stacker_greedy" in BotRoster.default_names()).is_false()
