extends GdUnitTestSuite
## The nine-only house rule (spec §3.2): only a two-card 9 is a natural. A
## two-card 8 no longer ends the hand; both sides play on by the third-card
## rules. Piles deal player, banker, player, banker, then the third cards.

const RULE: String = "nine_only"
const BET: int = BaccaratRoundFixture.BET

var _f: BaccaratRoundFixture


func before_test() -> void:
	_f = BaccaratRoundFixture.new()


func _under_the_rule() -> void:
	_f.rules = BaccaratRules.from_config(_f.config.for_house_rule(RULE))


func test_the_rule_raises_the_natural_to_nine() -> void:
	# §3.2: a natural is a two-card 8 or 9; under the rule, a 9 only.
	assert_int(_f.rules.natural_min).is_equal(8)
	_under_the_rule()
	assert_int(_f.rules.natural_min).is_equal(9)


func test_a_players_two_card_8_ends_the_hand_without_the_rule() -> void:
	var rnd: BaccaratRound = _f.dealt(["8", "3", "K", "K", "5"])
	var windows: Array[BaccaratRound.WindowKind] = BaccaratRoundFixture.play_out(rnd)
	assert_array(windows).is_equal([BaccaratRound.WindowKind.INITIAL])
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.PLAYER)


func test_a_players_two_card_8_plays_on_under_the_rule() -> void:
	# Player 8 stands; banker 3 draws against a standing player and makes 8.
	_under_the_rule()
	var rnd: BaccaratRound = _f.dealt(["8", "3", "K", "K", "5"])
	var windows: Array[BaccaratRound.WindowKind] = BaccaratRoundFixture.play_out(rnd)
	assert_array(windows).is_equal(
		[BaccaratRound.WindowKind.INITIAL, BaccaratRound.WindowKind.BANKER_THIRD]
	)
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	assert_int(rnd.banker_hand.cards.size()).is_equal(3)
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.TIE)
	assert_int(rnd.net()).is_equal(0)


func test_a_bankers_two_card_8_plays_on_under_the_rule() -> void:
	# Player 4 draws a 5 for 9; banker 8 stands and loses.
	_under_the_rule()
	var rnd: BaccaratRound = _f.dealt(["4", "8", "K", "K", "5", "2"])
	var windows: Array[BaccaratRound.WindowKind] = BaccaratRoundFixture.play_out(rnd)
	assert_array(windows).is_equal(
		[BaccaratRound.WindowKind.INITIAL, BaccaratRound.WindowKind.PLAYER_THIRD]
	)
	assert_int(rnd.banker_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.PLAYER)
	assert_int(rnd.net()).is_equal(BET)


func test_a_two_card_9_still_ends_the_hand() -> void:
	_under_the_rule()
	var rnd: BaccaratRound = _f.dealt(["9", "3", "K", "K", "5"])
	var windows: Array[BaccaratRound.WindowKind] = BaccaratRoundFixture.play_out(rnd)
	assert_array(windows).is_equal([BaccaratRound.WindowKind.INITIAL])
	assert_int(rnd.banker_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.PLAYER)


func test_an_8_against_a_9_loses_to_the_natural() -> void:
	_under_the_rule()
	var rnd: BaccaratRound = _f.dealt(["8", "9", "K", "K", "5"])
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.BANKER)


func test_a_table_under_the_rule_plays_it() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.house_rule = RULE
	var session: TableSession = fixture.sit(GameKind.Kind.BACCARAT, ["8", "3", "K", "K", "5"])
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	var rnd: BaccaratRound = session.current_round()
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.TIE)


func test_a_winning_two_card_8_pays_dragon_bonus_by_its_margin() -> void:
	# §8: player 8 beats banker 3 (who draws a ten) by 5, no longer a natural.
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.house_rule = RULE
	var session: TableSession = fixture.sit(GameKind.Kind.BACCARAT, ["8", "3", "K", "K", "10"])
	var side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER
	var bets: Array[SideBet] = [SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, 500, side)]
	session.start_hand(TableSessionFixture.BET, side, bets)
	TableSessionFixture.play_out(session)
	var pays: int = SideBetRules.from_config(fixture.config).dragon_bonus[1]
	assert_int(session.current_round().side_net()).is_equal(500 * pays)
