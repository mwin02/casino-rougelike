extends GdUnitTestSuite
## The table session (block 7) reads every game through GameRound: whether
## the round has resolved, and what it won or lost.


func test_blackjack_resolves_through_game_round() -> void:
	var f: BlackjackRoundFixture = BlackjackRoundFixture.new()
	# Player 20, dealer 16 draws a King and busts.
	var rnd: BlackjackRound = f.at_turn(["10", "9", "10", "7", "K"])
	var generic: GameRound = rnd
	assert_bool(generic.is_resolved()).is_false()
	BlackjackRoundFixture.stand(rnd)
	assert_bool(generic.is_resolved()).is_true()
	assert_int(generic.net()).is_equal(BlackjackRoundFixture.BET)


func test_baccarat_resolves_through_game_round() -> void:
	var f: BaccaratRoundFixture = BaccaratRoundFixture.new()
	# Player 9 natural against banker 0.
	var rnd: BaccaratRound = f.dealt(["4", "K", "5", "K"])
	var generic: GameRound = rnd
	assert_bool(generic.is_resolved()).is_false()
	BaccaratRoundFixture.play_out(rnd)
	assert_bool(generic.is_resolved()).is_true()
	assert_int(generic.net()).is_equal(BaccaratRoundFixture.BET)


func test_high_low_resolves_through_game_round() -> void:
	var f: HighLowRoundFixture = HighLowRoundFixture.new()
	# The last card wins "higher", and the chain banks itself.
	var rnd: HighLowRound = f.dealt(["2", "9"])
	var generic: GameRound = rnd
	assert_bool(generic.is_resolved()).is_false()
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	assert_bool(generic.is_resolved()).is_true()
	assert_int(generic.net()).is_equal(rnd.chain_value - HighLowRoundFixture.BET)
