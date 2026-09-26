extends GdUnitTestSuite
## Blackjack doubles (spec §3.1): a bet change, one card, then stand.

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


func test_double_opens_a_window_then_takes_one_card_and_stands() -> void:
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "7", "9"])
	rnd.double()
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.BEFORE_HIT)
	assert_int(rnd.hands[0].cards.size()).is_equal(2)
	rnd.proceed()
	rnd.proceed()
	assert_int(rnd.hands[0].cards.size()).is_equal(3)
	assert_int(rnd.hands[0].total()).is_equal(20)
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.FINAL)


func test_double_doubles_the_stake_and_records_a_bet_change() -> void:
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "7", "9"])
	rnd.double()
	assert_int(rnd.hands[0].stake).is_equal(2 * BET)
	assert_int(rnd.total_bet()).is_equal(2 * BET)
	assert_int(rnd.opening_bet).is_equal(BET)
	assert_int(rnd.bet_changes.size()).is_equal(1)
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.DOUBLE)
	assert_int(change.amount).is_equal(BET)
	assert_int(change.hand_index).is_equal(0)


func test_honest_hand_records_no_bet_changes() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "7", "9"])
	BlackjackRoundFixture.stand(rnd)
	assert_bool(rnd.bet_changes.is_empty()).is_true()
	assert_int(rnd.total_bet()).is_equal(BET)


func test_double_only_on_two_cards() -> void:
	var rnd: BlackjackRound = _f.at_turn(["2", "10", "3", "7", "4", "9"])
	assert_bool(rnd.can_double()).is_true()
	BlackjackRoundFixture.hit(rnd)
	assert_bool(rnd.can_double()).is_false()
	rnd.double()
	_assert_phase(rnd, BlackjackRound.Phase.PLAYER_TURN, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.hands[0].stake).is_equal(BET)


func test_no_double_after_the_bet_locks() -> void:
	# Spec §2.2: a manipulation locks the bet; no doubling afterwards.
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "7", "9"])
	rnd.lock_bet()
	assert_bool(rnd.can_double()).is_false()
	rnd.double()
	assert_int(rnd.hands[0].stake).is_equal(BET)
	assert_bool(rnd.bet_changes.is_empty()).is_true()
	assert_bool(rnd.can_hit()).is_true()


func test_double_that_busts_resolves_at_once() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "6", "7", "9"])
	BlackjackRoundFixture.double(rnd)
	_assert_phase(rnd, BlackjackRound.Phase.RESOLVED, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.net()).is_equal(-2 * BET)


func test_dealer_natural_takes_the_doubled_stake() -> void:
	# No peek: the dealer's natural is found at resolution and beats every stake.
	var rnd: BlackjackRound = _f.at_turn(["5", "A", "6", "K", "10"])
	BlackjackRoundFixture.double(rnd)
	rnd.proceed()
	assert_int(rnd.hands[0].total()).is_equal(21)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.LOSE)
	assert_int(rnd.net()).is_equal(-2 * BET)


func test_doubled_win_pays_double() -> void:
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "7", "9"])
	BlackjackRoundFixture.double(rnd)
	rnd.proceed()
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.WIN)
	assert_int(rnd.net()).is_equal(2 * BET)


func test_doubled_loss_costs_double() -> void:
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "9", "2"])
	BlackjackRoundFixture.double(rnd)
	rnd.proceed()
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.LOSE)
	assert_int(rnd.net()).is_equal(-2 * BET)


func test_doubled_push_returns_the_stake() -> void:
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "10", "9"])
	BlackjackRoundFixture.double(rnd)
	rnd.proceed()
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.PUSH)
	assert_int(rnd.net()).is_equal(0)


func test_doubled_hand_wins_double_on_dealer_bust() -> void:
	# Dealer 16 draws K: 26.
	var rnd: BlackjackRound = _f.at_turn(["5", "10", "6", "6", "9", "K"])
	BlackjackRoundFixture.double(rnd)
	rnd.proceed()
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.DEALER_BUST)
	assert_int(rnd.net()).is_equal(2 * BET)
