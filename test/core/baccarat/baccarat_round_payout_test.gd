extends GdUnitTestSuite
## Baccarat payouts (spec §3.2): Player 1:1, Banker 1:1 less commission
## (rounded down, §6.2), Tie at the tie payout. A tie pushes Player and Banker.

const BET: int = BaccaratRoundFixture.BET
## Player 7, banker 6, nobody draws.
const PLAYER_WINS: Array[String] = ["3", "3", "4", "3"]
## Player 6, banker 7.
const BANKER_WINS: Array[String] = ["3", "3", "3", "4"]
## Both 7.
const TIE: Array[String] = ["3", "3", "4", "4"]

var _f: BaccaratRoundFixture


func before_test() -> void:
	_f = BaccaratRoundFixture.new()


func _played(
	codes: Array[String], side: BaccaratRound.BetSide, stake: int = BET
) -> BaccaratRound:
	var rnd: BaccaratRound = _f.dealt(codes, side, stake)
	BaccaratRoundFixture.play_out(rnd)
	return rnd


func _banker_win(stake: int) -> int:
	return Money.apply_ratio(stake, 100 - _f.rules.banker_commission_pct, 100)


# gdlint: ignore=unused-argument
func test_outcomes(codes: Array, expected: BaccaratRound.Outcome, test_parameters: Array = [
	[PLAYER_WINS, BaccaratRound.Outcome.PLAYER],
	[BANKER_WINS, BaccaratRound.Outcome.BANKER],
	[TIE, BaccaratRound.Outcome.TIE],
	# Player natural 8 beats banker 7 before any third card.
	[["8", "3", "K", "4"], BaccaratRound.Outcome.PLAYER],
]) -> void:
	var pile: Array[String] = []
	pile.assign(codes)
	assert_int(_played(pile, BaccaratRound.BetSide.PLAYER).outcome).is_equal(expected)


func test_player_bet() -> void:
	assert_int(_played(PLAYER_WINS, BaccaratRound.BetSide.PLAYER).net()).is_equal(BET)
	assert_int(_played(BANKER_WINS, BaccaratRound.BetSide.PLAYER).net()).is_equal(-BET)
	assert_int(_played(TIE, BaccaratRound.BetSide.PLAYER).net()).is_equal(0)


func test_banker_bet_pays_less_commission() -> void:
	assert_int(_played(BANKER_WINS, BaccaratRound.BetSide.BANKER).net()).is_equal(_banker_win(BET))
	assert_int(_played(PLAYER_WINS, BaccaratRound.BetSide.BANKER).net()).is_equal(-BET)
	assert_int(_played(TIE, BaccaratRound.BetSide.BANKER).net()).is_equal(0)


func test_banker_commission_rounds_down() -> void:
	# Spec §3.2 commission 5%: 1010 wins 959.5, paid as 959.
	assert_int(_played(BANKER_WINS, BaccaratRound.BetSide.BANKER, 1010).net()).is_equal(959)
	assert_int(_played(BANKER_WINS, BaccaratRound.BetSide.BANKER, 1000).net()).is_equal(950)


func test_tie_bet() -> void:
	var tie_win: int = Money.apply_ratio(BET, _f.rules.tie_payout_num, _f.rules.tie_payout_den)
	assert_int(_played(TIE, BaccaratRound.BetSide.TIE).net()).is_equal(tie_win)
	assert_int(_played(PLAYER_WINS, BaccaratRound.BetSide.TIE).net()).is_equal(-BET)
	assert_int(_played(BANKER_WINS, BaccaratRound.BetSide.TIE).net()).is_equal(-BET)


func test_a_switched_bet_settles_on_the_new_side() -> void:
	var rnd: BaccaratRound = _f.dealt(BANKER_WINS, BaccaratRound.BetSide.PLAYER)
	rnd.proceed()
	rnd.switch_side()
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.net()).is_equal(_banker_win(BET))


func test_no_net_before_resolution() -> void:
	var rnd: BaccaratRound = _f.dealt(PLAYER_WINS, BaccaratRound.BetSide.PLAYER)
	assert_int(rnd.outcome).is_equal(BaccaratRound.Outcome.NONE)
	assert_int(rnd.net()).is_equal(0)
