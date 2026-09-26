extends GdUnitTestSuite
## High or Low phases (spec §3.3): one card up, then per call a window on the
## next card, an adjust before the first call only, and the call. A correct
## call leads to bank or continue. The bet locks when the chain starts.

const HIGHER: HighLowRound.Direction = HighLowRound.Direction.HIGHER
const LOWER: HighLowRound.Direction = HighLowRound.Direction.LOWER
const PILE: Array[String] = ["5S", "9S", "3S", "KS", "7S"]

var _f: HighLowRoundFixture


func before_test() -> void:
	_f = HighLowRoundFixture.new()


func test_deal_shows_one_card_and_opens_a_window() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.WINDOW)
	assert_int(rnd.cards.size()).is_equal(1)
	assert_str(rnd.current().short_name()).is_equal("5S")
	assert_int(rnd.chain_value).is_equal(HighLowRoundFixture.BET)


func test_the_first_call_has_a_window_then_an_adjust() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	assert_bool(rnd.can_adjust()).is_false()
	rnd.proceed()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.ADJUST)
	assert_bool(rnd.can_adjust()).is_true()
	rnd.proceed()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.CALL)
	assert_int(rnd.cards.size()).is_equal(1)


func test_a_correct_call_offers_bank_or_continue() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.DECIDE)
	rnd.continue_chain()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.WINDOW)


func test_the_bet_locks_when_the_chain_starts() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	assert_bool(rnd.is_bet_locked()).is_false()
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_bool(rnd.is_bet_locked()).is_true()
	rnd.continue_chain()
	# The next call's window goes straight to the call: no adjust mid-chain.
	rnd.proceed()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.CALL)
	assert_bool(rnd.can_adjust()).is_false()


func test_a_manipulation_locks_the_bet_before_the_first_call() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	rnd.lock_bet()
	rnd.proceed()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.ADJUST)
	assert_bool(rnd.can_adjust()).is_false()


func test_bank_resolves_the_chain() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, HIGHER)
	rnd.bank()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.BANKED)


func test_calls_only_happen_in_the_call_phase() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	rnd.call_next(HIGHER)
	rnd.bank()
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.WINDOW)
	assert_int(rnd.cards.size()).is_equal(1)


func test_any_call_is_allowed_and_one_with_no_winners_loses() -> void:
	var rnd: HighLowRound = _f.dealt(["KS", "5S", "3S"])
	assert_int(rnd.winners(HIGHER)).is_equal(0)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.LOST)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)


func test_a_wrong_call_ends_the_chain() -> void:
	var rnd: HighLowRound = _f.dealt(PILE)
	HighLowRoundFixture.take(rnd, LOWER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.LOST)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)


func test_the_chain_banks_itself_when_the_pile_runs_out() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "9S"])
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.RESOLVED)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.BANKED)


func test_counts_each_window_opened() -> void:
	var rnd: HighLowRound = _f.dealt(["5", "9", "K", "2"])
	assert_int(rnd.window_number).is_equal(1)
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	assert_int(rnd.window_number).is_equal(2)
