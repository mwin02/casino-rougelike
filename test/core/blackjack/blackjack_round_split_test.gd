extends GdUnitTestSuite
## Blackjack splits (spec §3.1): same rank only, each split hand is an extra
## life with its own stake. On a split the active hand, then the new hand,
## each take a card, with no window.

const BET: int = BlackjackRoundFixture.BET

var _f: BlackjackRoundFixture


func before_test() -> void:
	_f = BlackjackRoundFixture.new()


func _pile_of_eights() -> Array[String]:
	var codes: Array[String] = ["8", "10", "8", "7"]
	for i: int in 20:
		codes.append("8")
	return codes


func test_split_makes_two_hands_each_with_the_opening_stake() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2"])
	assert_bool(rnd.can_split()).is_true()
	rnd.split()
	assert_int(rnd.hands.size()).is_equal(2)
	assert_int(rnd.hands[0].total()).is_equal(11)
	assert_int(rnd.hands[1].total()).is_equal(10)
	assert_int(rnd.hands[0].stake).is_equal(BET)
	assert_int(rnd.hands[1].stake).is_equal(BET)
	assert_int(rnd.total_bet()).is_equal(2 * BET)


func test_split_records_a_bet_change() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2"])
	rnd.split()
	assert_int(rnd.bet_changes.size()).is_equal(1)
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.SPLIT)
	assert_int(change.amount).is_equal(BET)
	assert_int(change.hand_index).is_equal(1)


func test_split_cards_get_no_window() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2"])
	rnd.split()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.PLAYER_TURN)
	assert_int(rnd.active_hand_index).is_equal(0)


func test_split_needs_the_same_rank() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "7", "3", "2"])
	assert_bool(rnd.can_split()).is_false()
	rnd.split()
	assert_int(rnd.hands.size()).is_equal(1)
	assert_bool(rnd.bet_changes.is_empty()).is_true()


func test_split_only_on_two_cards() -> void:
	var rnd: BlackjackRound = _f.at_turn(["2", "10", "2", "7", "2"])
	BlackjackRoundFixture.hit(rnd)
	assert_bool(rnd.can_split()).is_false()


func test_no_split_after_the_bet_locks() -> void:
	# Spec §2.2: a manipulation locks the bet; no splitting afterwards.
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2"])
	rnd.lock_bet()
	assert_bool(rnd.can_split()).is_false()
	rnd.split()
	assert_int(rnd.hands.size()).is_equal(1)


func test_resplits_stop_at_the_hand_cap() -> void:
	var rnd: BlackjackRound = _f.at_turn(_pile_of_eights())
	while rnd.can_split():
		rnd.split()
	assert_int(rnd.hands.size()).is_equal(_f.rules.max_split_hands)
	assert_int(rnd.bet_changes.size()).is_equal(_f.rules.max_split_hands - 1)
	assert_int(rnd.total_bet()).is_equal(_f.rules.max_split_hands * BET)


func test_resplit_records_point_at_the_hands_they_made() -> void:
	var rnd: BlackjackRound = _f.at_turn(_pile_of_eights())
	while rnd.can_split():
		rnd.split()
	for i: int in rnd.bet_changes.size():
		var change: BetChange = rnd.bet_changes[i]
		assert_int(change.hand_index).is_equal(i + 1)
		assert_int(rnd.hands[change.hand_index].stake).is_equal(change.amount)


func test_standing_moves_to_the_next_hand() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2"])
	rnd.split()
	rnd.stand()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.PLAYER_TURN)
	assert_int(rnd.active_hand_index).is_equal(1)
	rnd.stand()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.WINDOW)
	assert_int(rnd.window).is_equal(BlackjackRound.WindowKind.FINAL)


func test_a_bust_split_hand_is_an_extra_life() -> void:
	# Hand 0: 8+K busts on a 5. Hand 1: 8+3 hits 9 for 20 against 17.
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "K", "3", "5", "9"])
	rnd.split()
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.PLAYER_TURN)
	assert_int(rnd.active_hand_index).is_equal(1)
	BlackjackRoundFixture.hit(rnd)
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.hands[0].outcome).is_equal(BlackjackHand.Outcome.PLAYER_BUST)
	assert_int(rnd.hands[1].outcome).is_equal(BlackjackHand.Outcome.WIN)
	assert_int(rnd.net()).is_equal(0)


func test_every_split_hand_bust_skips_the_dealer() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "6", "K", "K", "5", "5"])
	rnd.split()
	BlackjackRoundFixture.hit(rnd)
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.RESOLVED)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.net()).is_equal(-2 * BET)


func test_split_aces_play_on() -> void:
	var rnd: BlackjackRound = _f.at_turn(["A", "10", "A", "7", "5", "6", "4"])
	rnd.split()
	assert_bool(rnd.can_hit()).is_true()
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.hands[0].cards.size()).is_equal(3)
	assert_int(rnd.hands[0].total()).is_equal(20)
	assert_int(rnd.active_hand_index).is_equal(0)


func test_split_ace_and_ten_is_21_not_a_natural() -> void:
	# Hand 0: A+K is 21 at even money. Hand 1: A+9 is 20. Dealer 17.
	var rnd: BlackjackRound = _f.at_turn(["A", "10", "A", "7", "K", "9"])
	rnd.split()
	assert_int(rnd.hands[0].total()).is_equal(21)
	assert_bool(rnd.hands[0].is_natural()).is_false()
	assert_int(rnd.phase).is_equal(BlackjackRound.Phase.PLAYER_TURN)
	rnd.stand()
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.hands[0].outcome).is_equal(BlackjackHand.Outcome.WIN)
	assert_int(rnd.hands[1].outcome).is_equal(BlackjackHand.Outcome.WIN)
	assert_int(rnd.net()).is_equal(2 * BET)


func test_double_after_split() -> void:
	# Hand 0: 8+3 doubles, draws 9 for 20. Hand 1: 8+2 stands on 10.
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2", "9"])
	rnd.split()
	assert_bool(rnd.can_double()).is_true()
	BlackjackRoundFixture.double(rnd)
	assert_int(rnd.active_hand_index).is_equal(1)
	assert_int(rnd.hands[0].stake).is_equal(2 * BET)
	assert_int(rnd.total_bet()).is_equal(3 * BET)
	assert_int(rnd.bet_changes[1].kind).is_equal(BetChange.Kind.DOUBLE)
	assert_int(rnd.bet_changes[1].hand_index).is_equal(0)
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.net()).is_equal(2 * BET - BET)


func test_dealer_natural_takes_every_split_stake() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "A", "8", "K", "3", "2"])
	rnd.split()
	rnd.stand()
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.hands[0].outcome).is_equal(BlackjackHand.Outcome.LOSE)
	assert_int(rnd.hands[1].outcome).is_equal(BlackjackHand.Outcome.LOSE)
	assert_int(rnd.net()).is_equal(-2 * BET)
