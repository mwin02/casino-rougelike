extends GdUnitTestSuite
## Baccarat bet adjusts (spec §1.3, §3.2): the stake moves within 3× and 0.5×
## of the opening bet, in any adjust, alongside side switching.

const BET: int = BaccaratRoundFixture.BET

var _f: BaccaratRoundFixture


func before_test() -> void:
	_f = BaccaratRoundFixture.new()


## 2+3 vs A+A: both sides draw, so all three windows open.
func _no_natural() -> BaccaratRound:
	return _f.dealt(["2", "A", "3", "A", "A", "A"])


func test_adjust_moves_the_stake() -> void:
	var rnd: BaccaratRound = _no_natural()
	rnd.proceed()
	assert_bool(rnd.can_adjust()).is_true()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(2 * BET)
	assert_int(rnd.total_bet()).is_equal(2 * BET)
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.ADJUST)
	assert_int(change.amount).is_equal(BET)


func test_adjust_stops_at_the_limits() -> void:
	var rnd: BaccaratRound = _no_natural()
	rnd.proceed()
	rnd.adjust(3 * BET + 1)
	rnd.adjust(BET / 2 - 1)
	assert_int(rnd.stake).is_equal(BET)
	rnd.adjust(3 * BET)
	rnd.adjust(BET / 2)
	assert_int(rnd.stake).is_equal(BET / 2)


func test_limits_stay_against_the_opening_bet() -> void:
	var rnd: BaccaratRound = _no_natural()
	rnd.proceed()
	rnd.adjust(3 * BET)
	rnd.proceed()
	rnd.proceed()
	assert_int(rnd.adjust_max()).is_equal(3 * BET)
	assert_int(rnd.adjust_min()).is_equal(BET / 2)


func test_adjust_in_every_adjust_phase() -> void:
	var rnd: BaccaratRound = _no_natural()
	var adjusts: int = 0
	while rnd.phase != BaccaratRound.Phase.RESOLVED:
		if rnd.phase == BaccaratRound.Phase.ADJUST:
			assert_bool(rnd.can_adjust()).is_true()
			adjusts += 1
		else:
			assert_bool(rnd.can_adjust()).is_false()
		rnd.proceed()
	assert_int(adjusts).is_equal(3)


func test_a_tie_bet_adjusts_too() -> void:
	var rnd: BaccaratRound = _f.dealt(["2", "A", "3", "A", "A", "A"], BaccaratRound.BetSide.TIE)
	rnd.proceed()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(2 * BET)


func test_no_adjust_after_the_bet_locks() -> void:
	var rnd: BaccaratRound = _no_natural()
	rnd.proceed()
	rnd.lock_bet()
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(BET)
