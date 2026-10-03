extends GdUnitTestSuite
## Side bets at a table session (spec §8): placed with the opening bet, each
## capped at a share of table max, paid for by the bankroll, and never a
## source of heat. Card i has id i.

const BET: int = TableSessionFixture.BET
const STAKE: int = 500

var _f: TableSessionFixture
var _cap: int


func before_test() -> void:
	_f = TableSessionFixture.new()
	_cap = SideBetRules.from_config(_f.config).cap(TableSessionFixture.TABLE_MAX)


## Player 7H 7D against dealer 10 + 9: stands on 14 and loses; Perfect
## Pairs (coloured) wins.
func _pairs_table(bankroll: int = TableSessionFixture.BANKROLL) -> TableSession:
	return _f.sit(GameKind.Kind.BLACKJACK, ["7H", "10", "7D", "9", "K", "K"], bankroll)


func _pairs(stake: int = STAKE) -> Array[SideBet]:
	return [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, stake)]


func test_side_bets_ride_with_the_opening_bet() -> void:
	var session: TableSession = _pairs_table()
	assert_object(session.start_hand(BET, BaccaratRound.BetSide.PLAYER, _pairs())).is_not_null()
	assert_int(session.current_round().side_bets.size()).is_equal(1)


func test_side_bet_capped_at_a_share_of_table_max() -> void:
	var session: TableSession = _pairs_table()
	assert_bool(session.can_start_hand(BET, _pairs(_cap))).is_true()
	assert_bool(session.can_start_hand(BET, _pairs(_cap + 1))).is_false()
	assert_bool(session.can_start_hand(BET, _pairs(0))).is_false()


func test_side_bet_must_belong_to_the_game() -> void:
	var session: TableSession = _pairs_table()
	var bets: Array[SideBet] = [SideBet.exact_rank(STAKE, 5)]
	assert_bool(session.can_start_hand(BET, bets)).is_false()


func test_one_side_bet_of_each_kind() -> void:
	var session: TableSession = _pairs_table()
	var bets: Array[SideBet] = _pairs()
	bets.append_array(_pairs())
	assert_bool(session.can_start_hand(BET, bets)).is_false()


func test_bankroll_covers_the_opening_bet_and_side_bets() -> void:
	var session: TableSession = _pairs_table(BET + STAKE)
	assert_bool(session.can_start_hand(BET, _pairs())).is_true()
	assert_bool(session.can_start_hand(BET, _pairs(STAKE + 1))).is_false()
	session.start_hand(BET, BaccaratRound.BetSide.PLAYER, _pairs())
	# No raise can reach the money on the side bet.
	assert_int(session.current_round().limits.max_total()).is_equal(BET)


func test_a_placed_bet_cannot_change_mid_hand() -> void:
	var session: TableSession = _pairs_table()
	var bets: Array[SideBet] = _pairs()
	session.start_hand(BET, BaccaratRound.BetSide.PLAYER, bets)
	bets[0].stake = _cap * 10
	bets.append(SideBet.new(SideBetKind.Kind.BUST_IT, STAKE))
	assert_int(session.current_round().side_bets.size()).is_equal(1)
	assert_int(session.current_round().side_bets[0].stake).is_equal(STAKE)


func test_side_bets_settle_into_the_bankroll_at_zero_heat() -> void:
	var session: TableSession = _pairs_table()
	session.start_hand(BET, BaccaratRound.BetSide.PLAYER, _pairs())
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	var side_win: int = STAKE * SideBetRules.from_config(_f.config).perfect_pairs[1]
	assert_int(summary.side_net).is_equal(side_win)
	assert_int(summary.net).is_equal(side_win - BET)
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL + side_win - BET)
	assert_float(summary.heat).is_equal(0.0)
	assert_bool(summary.straight).is_true()
	assert_array(summary.side_bets).has_size(1)
