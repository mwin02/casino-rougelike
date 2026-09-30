extends GdUnitTestSuite
## What each window's actions can reach (spec §2.5): the window's face-down
## subject cards, and every card in play. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func _subjects(rnd: GameRound) -> Array[int]:
	return ActionsFixture.ids(rnd.window_subjects())


func _in_play(rnd: GameRound) -> Array[int]:
	return ActionsFixture.ids(rnd.cards_in_play())


# Blackjack: player 0, dealer up 1, player 2, dealer hole 3, then draws.


func test_blackjack_hole_card_window_is_about_the_hole_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "5", "4"])
	assert_array(_subjects(rnd)).contains_exactly([3])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1, 2, 3])


func test_blackjack_before_hit_window_is_about_the_incoming_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "5", "4"])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	assert_array(_subjects(rnd)).contains_exactly([4])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1, 2, 3, 4])


func test_blackjack_final_window_is_about_the_hole_card_and_the_dealer_draw() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "5", "4"])
	rnd.proceed()
	rnd.proceed()
	rnd.stand()
	assert_array(_subjects(rnd)).contains_exactly([3, 4])


func test_blackjack_no_subjects_outside_a_window() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "5", "4"])
	rnd.proceed()
	assert_array(_subjects(rnd)).is_empty()
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1, 2, 3])


# Baccarat: player 0, banker 1, player 2, banker 3, then third cards.


func test_baccarat_initial_window_is_about_both_second_cards() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A", "A", "A"])
	assert_array(_subjects(rnd)).contains_exactly([2, 3])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1, 2, 3])


func test_baccarat_third_card_windows_are_about_the_incoming_card() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A", "A", "A"])
	rnd.proceed()
	rnd.proceed()
	assert_int(rnd.window).is_equal(BaccaratRound.WindowKind.PLAYER_THIRD)
	assert_array(_subjects(rnd)).contains_exactly([4])
	rnd.proceed()
	assert_int(rnd.window).is_equal(BaccaratRound.WindowKind.BANKER_THIRD)
	assert_array(_subjects(rnd)).contains_exactly([5])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1, 2, 3, 4, 5])


# High or Low: card 0 up, then the next cards.


func test_high_low_window_is_about_the_next_card() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "K", "2"])
	assert_array(_subjects(rnd)).contains_exactly([1])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([0, 1])


func test_high_low_earlier_chain_cards_leave_play() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "K", "2"])
	HighLowRoundFixture.take(rnd, HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	assert_array(_subjects(rnd)).contains_exactly([2])
	assert_array(_in_play(rnd)).contains_exactly_in_any_order([1, 2])


func test_upcoming_shows_the_next_cards_as_they_read() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "K"])
	assert_array(ActionsFixture.ids(rnd.upcoming(2))).contains_exactly([1, 2])
	assert_array(ActionsFixture.ids(rnd.upcoming(5))).contains_exactly([1, 2])


func test_blackjack_double_window_is_about_the_incoming_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "5", "4"])
	rnd.proceed()
	rnd.proceed()
	rnd.double()
	assert_array(_subjects(rnd)).contains_exactly([4])
