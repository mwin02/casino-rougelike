extends GdUnitTestSuite
## Blackjack dealer play and payouts for every result (spec §3.1).

const BET: int = BlackjackRoundFixture.BET

var _f: BlackjackRoundFixture


func before_test() -> void:
	_f = BlackjackRoundFixture.new()


func _assert_phase(
	rnd: BlackjackRound, phase: BlackjackRound.Phase, window: BlackjackRound.WindowKind
) -> void:
	assert_int(rnd.phase).is_equal(phase)
	assert_int(rnd.window).is_equal(window)


func _outcome(rnd: BlackjackRound) -> BlackjackHand.Outcome:
	return rnd.hands[0].outcome


func test_dealer_hits_soft_17() -> void:
	# Dealer A+6 is soft 17: hits, draws 4 for soft 21, stands.
	var rnd: BlackjackRound = _f.at_turn(["K", "A", "Q", "6", "4"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(3)
	assert_int(rnd.dealer_hand.total()).is_equal(21)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.LOSE)


func test_dealer_stands_on_soft_17_when_rule_off() -> void:
	_f.rules.dealer_hits_soft_17 = false
	var rnd: BlackjackRound = _f.at_turn(["K", "A", "Q", "6", "4"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)


func test_dealer_stands_on_hard_17() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "7", "4"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)


func test_dealer_stands_on_soft_18() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "A", "9", "7", "4"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)


func test_dealer_keeps_hitting_below_17() -> void:
	# 16, then A makes hard 17 (A as 11 would be 27).
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "6", "A"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.total()).is_equal(17)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)


func test_player_at_22_is_not_bust() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "8", "2"])
	BlackjackRoundFixture.hit(rnd)
	_assert_phase(rnd, BlackjackRound.Phase.PLAYER_TURN, BlackjackRound.WindowKind.NONE)
	BlackjackRoundFixture.stand(rnd)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)


func test_natural_pays_configured_payout() -> void:
	var rnd: BlackjackRound = _f.dealt(["A", "9", "K", "7"])
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.NATURAL)
	var rules: BlackjackRules = _f.rules
	var expected: int = Money.apply_ratio(BET, rules.natural_payout_num, rules.natural_payout_den)
	assert_int(rnd.net()).is_equal(expected)


func test_natural_pays_3_to_2_by_default() -> void:
	# Spec §3.1: blackjack pays 3:2 unless a floor signature changes it.
	var rnd: BlackjackRound = _f.dealt(["A", "9", "K", "7"])
	assert_int(rnd.net()).is_equal(1500)


func test_natural_pays_6_to_5_when_configured() -> void:
	# Floor 3's stingy-house signature (spec §5.3).
	_f.rules.natural_payout_num = 6
	_f.rules.natural_payout_den = 5
	var rnd: BlackjackRound = _f.dealt(["A", "9", "K", "7"])
	assert_int(rnd.net()).is_equal(1200)


func test_natural_against_natural_pushes() -> void:
	var rnd: BlackjackRound = _f.dealt(["A", "A", "K", "Q"])
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.PUSH)
	assert_int(rnd.net()).is_equal(0)


func test_dealer_natural_beats_player_22() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "A", "Q", "K", "2"])
	BlackjackRoundFixture.hit(rnd)
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.hands[0].total()).is_equal(22)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.LOSE)


func test_equal_totals_push() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "8", "8"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.PUSH)
	assert_int(rnd.net()).is_equal(0)


func test_lower_total_loses() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "7", "9"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.LOSE)
	assert_int(rnd.net()).is_equal(-BET)


func test_higher_total_wins_even_money() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "9", "8"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)
	assert_int(rnd.net()).is_equal(BET)


func test_dealer_bust_pays_even_money() -> void:
	# Dealer 16 draws K: 26.
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "2", "6", "K"])
	BlackjackRoundFixture.stand(rnd)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.DEALER_BUST)
	assert_int(rnd.net()).is_equal(BET)
