extends GdUnitTestSuite
## Blackjack insurance (spec §3.1): a regular adjust, offered in the adjust
## after the hole-card window when the dealer shows an ace. It pays on a
## dealer natural and counts toward the total bet.

const BET: int = BlackjackRoundFixture.BET

var _f: BlackjackRoundFixture


func before_test() -> void:
	_f = BlackjackRoundFixture.new()


## Dealt and in the adjust after the hole-card window.
func _at_adjust(codes: Array[String]) -> BlackjackRound:
	var rnd: BlackjackRound = _f.dealt(codes)
	rnd.proceed()
	return rnd


func _max(rnd: BlackjackRound) -> int:
	return rnd.insurance_max()


func test_offered_in_the_hole_card_adjust_with_an_ace_up() -> void:
	var rnd: BlackjackRound = _f.dealt(["9", "A", "7", "5"])
	assert_bool(rnd.can_insure()).is_false()
	rnd.proceed()
	assert_bool(rnd.can_insure()).is_true()
	rnd.proceed()
	assert_bool(rnd.can_insure()).is_false()


func test_not_offered_without_an_ace_up() -> void:
	var rnd: BlackjackRound = _at_adjust(["9", "K", "7", "A"])
	assert_bool(rnd.can_insure()).is_false()


func test_not_offered_in_the_adjust_before_a_hit() -> void:
	var rnd: BlackjackRound = _f.at_turn(["9", "A", "2", "5", "3"])
	rnd.hit()
	rnd.proceed()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.ADJUST)
	assert_bool(rnd.can_insure()).is_false()


func test_capped_at_half_the_opening_bet() -> void:
	# Spec §3.1: insurance is at most 50% of the opening bet.
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "5"])
	assert_int(_max(rnd)).is_equal(500)
	rnd.insure(_max(rnd) + 1)
	assert_int(rnd.insurance_stake).is_equal(0)
	rnd.insure(0)
	assert_int(rnd.insurance_stake).is_equal(0)
	rnd.insure(_max(rnd))
	assert_int(rnd.insurance_stake).is_equal(500)


func test_insures_once() -> void:
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "5"])
	rnd.insure(200)
	assert_bool(rnd.can_insure()).is_false()
	rnd.insure(300)
	assert_int(rnd.insurance_stake).is_equal(200)
	assert_int(rnd.bet_changes.size()).is_equal(1)


func test_recorded_as_a_bet_change() -> void:
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "5"])
	rnd.insure(_max(rnd))
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.INSURANCE)
	assert_int(change.amount).is_equal(_max(rnd))
	assert_int(change.hand_index).is_equal(BetChange.NO_HAND)
	assert_int(rnd.total_bet()).is_equal(BET + _max(rnd))


func test_not_after_the_bet_locks() -> void:
	# Spec §2.2: a manipulation locks the bet; no insurance afterwards.
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "5"])
	rnd.lock_bet()
	assert_bool(rnd.can_insure()).is_false()
	rnd.insure(100)
	assert_int(rnd.insurance_stake).is_equal(0)


func test_pays_on_a_dealer_natural() -> void:
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "K"])
	rnd.insure(_max(rnd))
	rnd.proceed()
	BlackjackRoundFixture.stand(rnd)
	var rules: BlackjackRules = _f.rules
	var num: int = rules.insurance_payout_num
	var paid: int = Money.apply_ratio(_max(rnd), num, rules.insurance_payout_den)
	assert_int(rnd.net()).is_equal(paid - BET)


func test_pays_2_to_1_by_default() -> void:
	# Spec §3.1: a full insurance stake exactly covers the lost main bet.
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "K"])
	rnd.insure(500)
	rnd.proceed()
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.net()).is_equal(0)


func test_lost_without_a_dealer_natural() -> void:
	# Player 19 beats dealer soft 18; the insurance stake is lost.
	var rnd: BlackjackRound = _at_adjust(["9", "A", "10", "7"])
	rnd.insure(500)
	rnd.proceed()
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.net()).is_equal(BET - 500)


func test_settles_even_when_every_hand_busts() -> void:
	var rnd: BlackjackRound = _at_adjust(["9", "A", "7", "K", "K"])
	rnd.insure(500)
	rnd.proceed()
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.RESOLVED)
	assert_int(rnd.net()).is_equal(0)


func test_insurance_is_ahead_in_the_hole_card_window_and_its_adjust() -> void:
	var rnd: BlackjackRound = _f.dealt(["9", "A", "7", "5", "4"])
	assert_bool(rnd.insurance_ahead()).is_true()
	rnd.proceed()
	assert_bool(rnd.insurance_ahead()).is_true()
	rnd.proceed()
	assert_bool(rnd.insurance_ahead()).is_false()
	rnd.hit()
	assert_bool(rnd.insurance_ahead()).is_false()
	rnd.proceed()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.ADJUST)
	assert_bool(rnd.insurance_ahead()).is_false()


func test_insurance_is_not_ahead_without_an_ace_up_or_once_locked() -> void:
	assert_bool(_f.dealt(["9", "K", "7", "5"]).insurance_ahead()).is_false()
	var rnd: BlackjackRound = _f.dealt(["9", "A", "7", "5"])
	rnd.lock_bet()
	assert_bool(rnd.insurance_ahead()).is_false()
