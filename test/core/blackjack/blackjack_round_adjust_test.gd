extends GdUnitTestSuite
## Blackjack bet adjusts (spec §1.3, §3.1). An adjust sets the active hand's
## stake. The limits apply to the total bet, so doubles, splits and insurance
## count toward the 3× raise cap.

const BET: int = BlackjackRoundFixture.BET

var _f: BlackjackRoundFixture


func before_test() -> void:
	_f = BlackjackRoundFixture.new()


## Dealt and in the adjust after the hole-card window.
func _in_adjust(codes: Array[String]) -> BlackjackRound:
	var rnd: BlackjackRound = _f.dealt(codes)
	rnd.proceed()
	return rnd


func test_adjust_raises_the_active_hand() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "9", "6", "7", "5"])
	assert_bool(rnd.can_adjust()).is_true()
	rnd.adjust(2500)
	assert_int(rnd.hands[0].stake).is_equal(2500)
	assert_int(rnd.total_bet()).is_equal(2500)


func test_adjust_is_recorded_as_a_bet_change() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "9", "6", "7", "5"])
	rnd.adjust(600)
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.ADJUST)
	assert_int(change.amount).is_equal(600 - BET)
	assert_int(change.hand_index).is_equal(0)


func test_adjust_stops_at_the_limits() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "9", "6", "7", "5"])
	assert_int(rnd.adjust_max()).is_equal(3 * BET)
	assert_int(rnd.adjust_min()).is_equal(BET / 2)
	rnd.adjust(3 * BET + 1)
	rnd.adjust(BET / 2 - 1)
	assert_int(rnd.total_bet()).is_equal(BET)
	assert_array(rnd.bet_changes).is_empty()


func test_adjust_to_the_same_bet_records_nothing() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "9", "6", "7", "5"])
	rnd.adjust(BET)
	assert_array(rnd.bet_changes).is_empty()


func test_no_adjust_outside_an_adjust_phase() -> void:
	var rnd: BlackjackRound = _f.dealt(["10", "9", "6", "7", "5"])
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2000)
	rnd.proceed()
	rnd.proceed()
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2000)
	assert_int(rnd.total_bet()).is_equal(BET)


func test_adjust_before_a_hit_moves_the_active_hand() -> void:
	var rnd: BlackjackRound = _f.at_turn(["8", "10", "8", "7", "3", "2", "5"])
	rnd.split()
	rnd.hit()
	rnd.proceed()
	rnd.adjust(2 * BET + 500)
	assert_int(rnd.hands[0].stake).is_equal(BET + 500)
	assert_int(rnd.hands[1].stake).is_equal(BET)
	assert_int(rnd.bet_changes.back().hand_index).is_equal(0)


func test_a_doubled_hand_cannot_drop_below_its_doubled_stake() -> void:
	var rnd: BlackjackRound = _f.at_turn(["10", "9", "6", "7", "5"])
	rnd.double()
	rnd.proceed()
	assert_int(rnd.adjust_min()).is_equal(2 * BET)
	rnd.adjust(BET)
	assert_int(rnd.total_bet()).is_equal(2 * BET)
	rnd.adjust(3 * BET)
	assert_int(rnd.total_bet()).is_equal(3 * BET)


func test_no_double_past_the_raise_cap() -> void:
	var rnd: BlackjackRound = _f.at_turn_with_bet(["10", "9", "6", "7", "5"], 2 * BET)
	assert_bool(rnd.can_double()).is_false()


func test_double_up_to_the_raise_cap() -> void:
	var rnd: BlackjackRound = _f.at_turn_with_bet(["10", "9", "6", "7", "5"], 3 * BET / 2)
	assert_bool(rnd.can_double()).is_true()


func test_splits_stop_at_the_raise_cap() -> void:
	# 3 hands at the opening stake reach 3×, before the 4-hand cap.
	var codes: Array[String] = ["8", "10", "8", "7"]
	for i: int in 20:
		codes.append("8")
	var rnd: BlackjackRound = _f.at_turn(codes)
	while rnd.can_split():
		rnd.split()
	assert_int(rnd.hands.size()).is_equal(3)
	assert_int(rnd.total_bet()).is_equal(3 * BET)


func test_insurance_capped_by_the_room_under_the_raise_cap() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "A", "6", "7", "5"])
	rnd.adjust(3 * BET - 200)
	assert_int(rnd.insurance_max()).is_equal(200)
	rnd.adjust(3 * BET)
	assert_bool(rnd.can_insure()).is_false()


func test_table_max_caps_the_total_bet() -> void:
	var pile: Array[Card] = []
	for code: String in ["10", "9", "6", "7", "5"]:
		pile.append(Card.parse(code))
	var limits: BetLimits = BetLimits.from_config(_f.config, BET, 100, 1500)
	var rnd: BlackjackRound = BlackjackRound.new(_f.rules, limits, pile)
	rnd.deal()
	rnd.proceed()
	assert_int(rnd.adjust_max()).is_equal(1500)
	rnd.proceed()
	assert_bool(rnd.can_double()).is_false()


func test_no_adjust_after_the_bet_locks() -> void:
	var rnd: BlackjackRound = _in_adjust(["10", "9", "6", "7", "5"])
	rnd.lock_bet()
	assert_bool(rnd.can_adjust()).is_false()
	rnd.adjust(2 * BET)
	assert_int(rnd.total_bet()).is_equal(BET)
