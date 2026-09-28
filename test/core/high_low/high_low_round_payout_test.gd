extends GdUnitTestSuite
## High or Low payouts (spec §3.3). Each correct call reprices the chain value
## (HighLowRules.call_value); banking pays the chain value less the stake. A
## tie keeps half the chain value (half the stake on the first call); a wrong
## call loses the stake. Caps: 3× per call, 20× stake for the chain.

const HIGHER: HighLowRound.Direction = HighLowRound.Direction.HIGHER
const LOWER: HighLowRound.Direction = HighLowRound.Direction.LOWER
const BET: int = HighLowRoundFixture.BET
const PILE: Array[String] = ["5S", "9S", "3S", "KS", "7S"]

var _f: HighLowRoundFixture


func before_test() -> void:
	_f = HighLowRoundFixture.new()


func test_banking_one_call_pays_the_formula() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, HIGHER)
	# 3 of 4 beat the 5: 4 × 93 / 300 = ×1.24.
	assert_int(rnd.chain_value).is_equal(_f.rules.call_value(BET, 3, 4))
	assert_int(rnd.chain_value).is_equal(1240)
	rnd.bank()
	assert_int(rnd.net()).is_equal(240)


func test_calls_compound_through_a_chain() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, HIGHER)
	HighLowRoundFixture.take(rnd, LOWER)
	# 2 of 3 are under the 9: ×1.395 on 1240 is 1729.8, rounded down.
	var two_calls: int = _f.rules.call_value(1240, 2, 3)
	assert_int(two_calls).is_equal(1729)
	assert_int(rnd.chain_value).is_equal(two_calls)
	HighLowRoundFixture.take(rnd, HIGHER)
	# Both remaining cards beat the 3: ×0.93, held at the 1× floor.
	assert_int(rnd.chain_value).is_equal(1729)
	rnd.bank()
	assert_int(rnd.net()).is_equal(729)


func test_a_first_call_tie_loses_half_the_stake() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "5H", "9S", "3S"])
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.TIE)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)
	assert_int(rnd.net()).is_equal(-500)


func test_a_tie_rounds_in_the_house_favour() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "5H", "9S", "3S"], 1001)
	HighLowRoundFixture.take(rnd, LOWER)
	assert_int(rnd.net()).is_equal(-501)


func test_a_mid_chain_tie_keeps_half_the_chain_value() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "9S", "9H", "3S"])
	HighLowRoundFixture.take(rnd, HIGHER)
	# 2 of 3 beat the 5: ×1.395.
	assert_int(rnd.chain_value).is_equal(1395)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.TIE)
	assert_int(rnd.chain_value).is_equal(697)
	assert_int(rnd.net()).is_equal(697 - BET)


func test_a_wrong_call_loses_the_stake() -> void:
	var first: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(first, LOWER)
	assert_int(first.net()).is_equal(-BET)
	var later: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(later, HIGHER)
	HighLowRoundFixture.take(later, HIGHER)
	assert_int(later.outcome).is_equal(HighLowRound.Outcome.LOST)
	assert_int(later.net()).is_equal(-BET)


func test_per_call_and_chain_caps() -> void:
	# Every call beats the aces left behind, so each is a long shot.
	var rnd: HighLowRound = _f.dealt(
		["2S", "3S", "4S", "5S", "AS", "AH", "AD", "AC", "AS", "AH", "AD"]
	)
	HighLowRoundFixture.take(rnd, HIGHER)
	# 3 of 10: ×3.1, held at 3×.
	assert_int(rnd.chain_value).is_equal(3000)
	HighLowRoundFixture.take(rnd, HIGHER)
	# 2 of 9: ×4.185, held at 3×.
	assert_int(rnd.chain_value).is_equal(9000)
	HighLowRoundFixture.take(rnd, HIGHER)
	# 27000 passes the 20× chain cap; the chain banks itself there.
	assert_int(rnd.chain_value).is_equal(20000)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.BANKED)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)
	assert_int(rnd.net()).is_equal(19000)


func test_no_net_before_resolution() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.net()).is_equal(0)


func test_a_call_is_priced_before_it_is_made() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	assert_int(rnd.value_if_won(HIGHER)).is_equal(1240)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.chain_value).is_equal(1240)
