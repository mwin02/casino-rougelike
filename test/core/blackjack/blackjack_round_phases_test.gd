extends GdUnitTestSuite
## Blackjack windows as explicit phases (spec §3.1): hole card, before each
## hit, and a final window after standing.

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


func test_deal_opens_the_hole_card_window_then_an_adjust() -> void:
	var rnd: BlackjackRound = _f.dealt(["2", "3", "4", "5"])
	assert_int(rnd.hands[0].cards.size()).is_equal(2)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.HOLE_CARD)
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.ADJUST, BlackjackRound.WindowKind.NONE)
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.PLAYER_TURN, BlackjackRound.WindowKind.NONE)


func test_play_actions_wait_for_the_players_turn() -> void:
	var rnd: BlackjackRound = _f.dealt(["2", "3", "4", "5", "6"])
	assert_bool(rnd.can_hit()).is_false()
	assert_bool(rnd.can_double()).is_false()
	rnd.hit()
	rnd.stand()
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.HOLE_CARD)
	assert_int(rnd.hands[0].cards.size()).is_equal(2)


func test_hit_opens_a_window_on_the_incoming_card_before_drawing() -> void:
	var rnd: BlackjackRound = _f.at_turn(["2", "K", "3", "7", "4"])
	rnd.hit()
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.BEFORE_HIT)
	assert_int(rnd.hands[0].cards.size()).is_equal(2)
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.ADJUST, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.hands[0].cards.size()).is_equal(2)
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.PLAYER_TURN, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.hands[0].total()).is_equal(9)


func test_every_hit_gets_its_own_window() -> void:
	var rnd: BlackjackRound = _f.at_turn(["2", "K", "3", "7", "2", "2"])
	for i: int in 2:
		rnd.hit()
		_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.BEFORE_HIT)
		rnd.proceed()
		rnd.proceed()
	assert_int(rnd.hands[0].total()).is_equal(9)


func test_stand_opens_the_final_window_before_the_dealer_plays() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "6", "5"])
	rnd.stand()
	_assert_phase(rnd, BlackjackRound.Phase.WINDOW, BlackjackRound.WindowKind.FINAL)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.RESOLVED, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(3)


func test_player_natural_resolves_with_no_windows() -> void:
	var rnd: BlackjackRound = _f.dealt(["A", "9", "K", "7"])
	_assert_phase(rnd, BlackjackRound.Phase.RESOLVED, BlackjackRound.WindowKind.NONE)


func test_bust_skips_the_final_window_and_the_dealer() -> void:
	var rnd: BlackjackRound = _f.at_turn(["K", "10", "Q", "6", "5"])
	BlackjackRoundFixture.hit(rnd)
	_assert_phase(rnd, BlackjackRound.Phase.RESOLVED, BlackjackRound.WindowKind.NONE)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.PLAYER_BUST)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.net()).is_equal(-BET)


func test_proceed_does_nothing_on_the_players_turn() -> void:
	var rnd: BlackjackRound = _f.at_turn(["2", "K", "3", "7", "4"])
	rnd.proceed()
	_assert_phase(rnd, BlackjackRound.Phase.PLAYER_TURN, BlackjackRound.WindowKind.NONE)
	assert_int(rnd.hands[0].cards.size()).is_equal(2)


func test_actions_ignored_after_resolution() -> void:
	var rnd: BlackjackRound = _f.dealt(["A", "9", "K", "7", "5"])
	rnd.hit()
	rnd.double()
	rnd.stand()
	rnd.proceed()
	assert_int(rnd.hands[0].cards.size()).is_equal(2)
	assert_int(_outcome(rnd)).is_equal(BlackjackHand.Outcome.NATURAL)


func test_counts_each_window_opened() -> void:
	var rnd: BlackjackRound = _f.dealt(["10", "9", "6", "7", "2", "5"])
	assert_int(rnd.window_number).is_equal(1)
	rnd.proceed()
	rnd.proceed()
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.window_number).is_equal(2)
	rnd.stand()
	assert_int(rnd.window_number).is_equal(3)
