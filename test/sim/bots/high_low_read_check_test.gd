extends GdUnitTestSuite
## The back-off check at High or Low (block 17): a look ahead there costs
## about 49 heat, so the bots that stand up (reveal-only, reveal + adjust,
## the Whale, the Mechanic) read only while the read and the largest raise
## stay short of a back-off (§7.1), as the Reader does. Otherwise they play
## the hand honestly and stand up. Reckless bots never check, a measurement
## session (no nerve) never checks, and nothing changes at the other games.

const CARDS: Array[String] = ["5", "9", "K", "2", "7", "3"]
## Table heat a High or Low read can't be added to without a back-off.
const HOT: float = 100.0

## Whether the bot wanted to stand after the last _used() hand.
var _stands: bool = false


func _bot(name: String) -> Bot:
	return BotRoster.build([name])[0]


## Plays one high-stakes hand at this table heat; returns the actions used.
func _used(bot: Bot, game: GameKind.Kind, heat: float) -> Array[ActionKind.Kind]:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.stakes = TableStakes.Kind.HIGH
	var session: TableSession = fixture.sit(game, CARDS)
	session.table_heat.heat = heat
	bot.begin_session(session, fixture.config, Deck.standard(0))
	# Floor and run modes seat a bot with its nerve; reckless bots take none.
	bot.take_nerve(Nerve.draw(1))
	var hand: HandActions = session.start_hand(bot.opening_bet(session), bot.baccarat_side(session))
	bot.play_hand(session, hand)
	var kinds: Array[ActionKind.Kind] = []
	for use: ActionUse in hand.used:
		kinds.append(use.action)
	_stands = bot.wants_to_stand(session)
	return kinds


func test_careful_bots_read_a_cool_high_or_low_table(
	name: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["reveal_only"], ["reveal_adjust"], ["whale"], ["mechanic"]]
) -> void:
	var used: Array[ActionKind.Kind] = _used(_bot(name), GameKind.Kind.HIGH_LOW, 0.0)
	assert_array(used).contains([ActionKind.Kind.LOOK_AHEAD])
	assert_bool(_stands).is_false()


func test_careful_bots_play_a_hot_high_or_low_table_honestly_and_leave(
	name: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["reveal_only"], ["reveal_adjust"], ["whale"], ["mechanic"]]
) -> void:
	var used: Array[ActionKind.Kind] = _used(_bot(name), GameKind.Kind.HIGH_LOW, HOT)
	assert_array(used).is_empty()
	assert_bool(_stands).is_true()


func test_reckless_bots_read_whatever_the_heat(
	name: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["reckless_chaser"], ["manipulate_max"]]
) -> void:
	var used: Array[ActionKind.Kind] = _used(_bot(name), GameKind.Kind.HIGH_LOW, HOT)
	assert_array(used).contains([ActionKind.Kind.LOOK_AHEAD])


func test_the_check_changes_nothing_at_the_other_games(
	name: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["reveal_only"], ["reveal_adjust"], ["whale"]]
) -> void:
	for game: GameKind.Kind in [GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT]:
		var used: Array[ActionKind.Kind] = _used(_bot(name), game, HOT)
		assert_array(used).contains([ActionKind.Kind.FULL_REVEAL])


func test_a_new_table_starts_unspent() -> void:
	var bot: Bot = _bot("whale")
	_used(bot, GameKind.Kind.HIGH_LOW, HOT)
	assert_bool(_stands).is_true()
	_used(bot, GameKind.Kind.HIGH_LOW, 0.0)
	assert_bool(_stands).is_false()


func test_a_measurement_session_reads_whatever_the_heat() -> void:
	# dph mode seats bots without a nerve and sits to the end (§3.4).
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.stakes = TableStakes.Kind.HIGH
	var session: TableSession = fixture.sit(GameKind.Kind.HIGH_LOW, CARDS)
	session.table_heat.heat = HOT
	var bot: Bot = _bot("reveal_adjust")
	bot.begin_session(session, fixture.config, Deck.standard(0))
	var hand: HandActions = session.start_hand(bot.opening_bet(session))
	bot.play_hand(session, hand)
	assert_int(hand.used.size()).is_equal(1)
