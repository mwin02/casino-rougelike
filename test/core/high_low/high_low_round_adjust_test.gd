extends GdUnitTestSuite
## High or Low bet adjusts (spec §1.3, §3.3): only in the adjust before the
## first call, within 3× and 0.5× of the opening bet. The adjusted stake is
## the chain's stake.

const BET: int = HighLowRoundFixture.BET

var _f: HighLowRoundFixture


func before_test() -> void:
	_f = HighLowRoundFixture.new()


func _in_adjust() -> HighLowRound:
	var rnd: HighLowRound = _f.dealt(["5", "9", "2", "K"])
	rnd.proceed()
	return rnd


func test_adjust_moves_the_stake_and_the_chain_value() -> void:
	var rnd: HighLowRound = _in_adjust()
	assert_bool(rnd.can_adjust()).is_true()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(2 * BET)
	assert_int(rnd.chain_value).is_equal(2 * BET)
	assert_int(rnd.total_bet()).is_equal(2 * BET)
	assert_int(rnd.bet_changes[0].kind).is_equal(BetChange.Kind.ADJUST)


func test_adjust_stops_at_the_limits() -> void:
	var rnd: HighLowRound = _in_adjust()
	rnd.adjust(3 * BET + 1)
	rnd.adjust(BET / 2 - 1)
	assert_int(rnd.stake).is_equal(BET)
	assert_array(rnd.bet_changes).is_empty()


func test_the_chain_starts_from_the_adjusted_stake() -> void:
	var rnd: HighLowRound = _in_adjust()
	rnd.adjust(BET / 2)
	var won_by: int = rnd.winners(HighLowRound.Direction.HIGHER)
	var out_of: int = rnd.remaining()
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	rnd.bank()
	assert_int(rnd.chain_value).is_equal(_f.rules.call_value(BET / 2, won_by, out_of))
	assert_int(rnd.net()).is_equal(rnd.chain_value - BET / 2)


func test_no_adjust_once_the_chain_starts() -> void:
	var rnd: HighLowRound = _in_adjust()
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	HighLowRoundFixture.to_call(rnd)
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(BET)


func test_no_adjust_after_the_bet_locks() -> void:
	var rnd: HighLowRound = _in_adjust()
	rnd.lock_bet()
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2 * BET)
	assert_int(rnd.stake).is_equal(BET)
