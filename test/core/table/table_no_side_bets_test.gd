extends GdUnitTestSuite
## The no-side-bets house rule (spec §5.2, §8): a table of any game that
## takes no side bets. The main game plays as usual.

const RULE: String = "no_side_bets"
const BET: int = TableSessionFixture.BET
const STAKE: int = 500

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


func _pairs() -> Array[SideBet]:
	return [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE)]


func _sit(rule: String) -> TableSession:
	_f.house_rule = rule
	return _f.sit(GameKind.Kind.BLACKJACK, ["7H", "10", "7D", "9", "K", "K"])


func test_a_table_offers_side_bets_by_default() -> void:
	var session: TableSession = _sit("")
	assert_bool(session.side_bets_offered()).is_true()
	assert_bool(session.can_start_hand(BET, _pairs())).is_true()
	assert_int(session.side_bet_cap()).is_greater(0)


func test_the_rule_applies_at_every_game() -> void:
	_f.house_rule = RULE
	for game: GameKind.Kind in GameKind.Kind.values():
		var session: TableSession = _f.sit(game, TableSessionFixture.repeat("7", 8))
		assert_bool(session.side_bets_offered()).is_false()
		assert_int(session.side_bet_cap()).is_equal(0)


func test_a_no_side_bets_table_refuses_every_side_bet() -> void:
	var session: TableSession = _sit(RULE)
	for kind: SideBetKind.Kind in SideBetKind.for_game(GameKind.Kind.BLACKJACK):
		var bets: Array[SideBet] = [SideBet.new(kind, 1)]
		assert_bool(session.can_start_hand(BET, bets)).is_false()
	assert_object(session.start_hand(BET, BaccaratRound.BetSide.PLAYER, _pairs())).is_null()
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL)


func test_the_main_game_plays_as_usual() -> void:
	# Player 7 + 7 stands on 14 against the dealer's 19.
	var session: TableSession = _sit(RULE)
	assert_object(session.start_hand(BET)).is_not_null()
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_int(summary.net).is_equal(-BET)
	assert_int(summary.side_net).is_equal(0)
