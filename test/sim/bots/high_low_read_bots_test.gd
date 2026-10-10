extends GdUnitTestSuite
## Reading bots at High or Low (block 17): with no full reveal there, they
## read the first call with look ahead. (That look ahead is refused on later
## calls is the core's test, high_low_reads_test.)

var _fixture: TableSessionFixture


func before_test() -> void:
	_fixture = TableSessionFixture.new()


## Plays one High or Low hand (5 up, then 9) and returns the actions it used.
func _used(bot: Bot, stakes: TableStakes.Kind = TableStakes.Kind.HIGH) -> Array[ActionKind.Kind]:
	_fixture.stakes = stakes
	var session: TableSession = _fixture.sit(GameKind.Kind.HIGH_LOW, ["5", "9", "K", "2", "7"])
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var hand: HandActions = session.start_hand(bot.opening_bet(session))
	bot.play_hand(session, hand)
	var kinds: Array[ActionKind.Kind] = []
	for use: ActionUse in hand.used:
		kinds.append(use.action)
	return kinds


func test_reading_bots_keep_look_ahead_in_their_kit() -> void:
	var bots: Array[Bot] = [
		RevealBot.new("reveal_only", false), ReaderBot.new(), ManipulateMaxBot.new(),
		RecklessChaserBot.new(),
	]
	for bot: Bot in bots:
		assert_array(bot.actions_used()).contains([ActionKind.Kind.LOOK_AHEAD])


func test_the_reveal_bot_reads_the_first_call_with_look_ahead() -> void:
	var used: Array[ActionKind.Kind] = _used(RevealBot.new("reveal_only", false))
	assert_array(used).contains_exactly([ActionKind.Kind.LOOK_AHEAD])


func test_the_reader_reads_the_first_call_with_look_ahead() -> void:
	var used: Array[ActionKind.Kind] = _used(ReaderBot.new())
	assert_array(used).contains_exactly([ActionKind.Kind.LOOK_AHEAD])


func test_manipulate_max_looks_ahead_before_it_acts() -> void:
	var used: Array[ActionKind.Kind] = _used(ManipulateMaxBot.new())
	assert_int(used[0]).is_equal(ActionKind.Kind.LOOK_AHEAD)
	assert_array(used).not_contains([ActionKind.Kind.FULL_REVEAL])


func test_the_reckless_chaser_looks_ahead_and_never_full_reveals() -> void:
	var used: Array[ActionKind.Kind] = _used(RecklessChaserBot.new())
	assert_int(used.count(ActionKind.Kind.LOOK_AHEAD)).is_equal(1)
	assert_array(used).not_contains([ActionKind.Kind.FULL_REVEAL])
