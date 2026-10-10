extends GdUnitTestSuite
## Manipulate-max (spec §2.2, §12): opens at the table maximum, reveals the
## card that decides the hand, and nudges or palms it when the hand is losing.

var _fixture: TableSessionFixture = TableSessionFixture.new()
## The round _play() played.
var _round: GameRound


## Plays one stacked hand and returns what was used in it.
func _play(game: GameKind.Kind, codes: Array[String]) -> HandActions:
	var session: TableSession = _fixture.sit(game, codes)
	var bot: ManipulateMaxBot = ManipulateMaxBot.new()
	# The bot prices on a standard deck, not the few stacked cards.
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var hand: HandActions = session.start_hand(bot.opening_bet(session), bot.baccarat_side(session))
	bot.play_hand(session, hand)
	_round = session.current_round()
	return hand


func _actions(hand: HandActions) -> Array[ActionKind.Kind]:
	var kinds: Array[ActionKind.Kind] = []
	for use: ActionUse in hand.used:
		kinds.append(use.action)
	return kinds


func test_it_opens_at_the_table_maximum() -> void:
	var session: TableSession = _fixture.sit(GameKind.Kind.BLACKJACK, ["10S", "10H"])
	assert_int(ManipulateMaxBot.new().opening_bet(session)).is_equal(TableSessionFixture.TABLE_MAX)


func test_a_winning_blackjack_hand_is_left_alone() -> void:
	# Player 10, 10 stands on 20; dealer 10 up, 7 in the hole: 17, stands.
	var hand: HandActions = _play(
		GameKind.Kind.BLACKJACK, ["10S", "10H", "10D", "7C", "5S", "5H", "5D", "5C"]
	)
	assert_array(_actions(hand)).contains_exactly([ActionKind.Kind.FULL_REVEAL])


func test_a_losing_blackjack_hand_is_rescued() -> void:
	# Player 10, 10 stands on 20; dealer 10 up, ace in the hole: a natural,
	# which beats every stake. Nudged to a 2, the dealer draws from 12.
	var hand: HandActions = _play(
		GameKind.Kind.BLACKJACK, ["10S", "10H", "10D", "AC", "5S", "5H", "5D", "5C"]
	)
	assert_array(_actions(hand)).contains_exactly(
		[ActionKind.Kind.FULL_REVEAL, ActionKind.Kind.NUDGE]
	)
	assert_int(_round.net()).is_greater(0)


func test_a_high_or_low_tie_is_nudged_into_a_win() -> void:
	# §3.3: High or Low takes no full reveal; the bot looks ahead.
	var hand: HandActions = _play(GameKind.Kind.HIGH_LOW, ["7S", "7H", "2D", "3C"])
	assert_array(_actions(hand)).contains_exactly(
		[ActionKind.Kind.LOOK_AHEAD, ActionKind.Kind.NUDGE]
	)
	var rnd: HighLowRound = _round
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.BANKED)


func test_a_losing_baccarat_hand_is_rescued() -> void:
	# Banker bet. Player 9 + 0 is a natural; banker 1 + 1 loses without help.
	var hand: HandActions = _play(
		GameKind.Kind.BACCARAT, ["9S", "AH", "10D", "AC", "5S", "5H", "5D", "5C"]
	)
	var kinds: Array[ActionKind.Kind] = _actions(hand)
	assert_int(kinds.count(ActionKind.Kind.FULL_REVEAL)).is_equal(2)
	assert_bool(ActionKind.Kind.NUDGE in kinds or ActionKind.Kind.PALM in kinds).is_true()


func test_it_wins_more_than_straight_play_for_its_heat() -> void:
	var args: Array[String] = ["--sessions=20", "--hands=10", "--seed=2", "--bots=manipulate_max"]
	var report: SimReport = SimRun.dollars_per_heat(SimOptions.parse(PackedStringArray(args)))
	for game: int in GameKind.Kind.values():
		var record: SimReport.Record = report.record(0, game as GameKind.Kind, "manipulate_max")
		assert_float(record.heat_per_hand()).is_greater(0.0)
		assert_float(record.edge()).is_greater(0.0)
