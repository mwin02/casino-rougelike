extends GdUnitTestSuite
## Baccarat windows as phases (spec §3.2): an initial window with both second
## cards face down, then a window before each third card that will be drawn.

const W := BaccaratRound.WindowKind

var _f: BaccaratRoundFixture


func before_test() -> void:
	_f = BaccaratRoundFixture.new()


func test_deal_opens_the_initial_window_with_second_cards_down() -> void:
	var rnd: BaccaratRound = _f.dealt(["3", "3", "4", "3"])
	assert_int(rnd.phase).is_equal(BaccaratRound.Phase.WINDOW)
	assert_int(rnd.window).is_equal(W.INITIAL)
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	assert_int(rnd.banker_hand.cards.size()).is_equal(2)
	assert_bool(rnd.second_cards_shown).is_false()


func test_second_cards_turn_over_after_the_initial_adjust() -> void:
	var rnd: BaccaratRound = _f.dealt(["3", "3", "4", "3"])
	rnd.proceed()
	assert_int(rnd.phase).is_equal(BaccaratRound.Phase.ADJUST)
	assert_bool(rnd.second_cards_shown).is_false()
	rnd.proceed()
	assert_bool(rnd.second_cards_shown).is_true()


# gdlint: ignore=unused-argument
func test_windows_before_third_cards(codes: Array, expected: Array, test_parameters: Array = [
	# Player natural 8: resolves after the initial adjust.
	[["8", "2", "K", "3"], [W.INITIAL]],
	# Banker natural 9.
	[["2", "4", "3", "5"], [W.INITIAL]],
	# Player 7, banker 6: nobody draws.
	[["3", "3", "4", "3"], [W.INITIAL]],
	# Player 5 draws a 5; banker 4 draws against a 5.
	[["2", "K", "3", "4", "5", "6"], [W.INITIAL, W.PLAYER_THIRD, W.BANKER_THIRD]],
	# Player 6 stands; banker 5 draws.
	[["3", "2", "3", "3", "K"], [W.INITIAL, W.BANKER_THIRD]],
	# Player 5 draws an 8; banker 3 stands against an 8.
	[["2", "3", "3", "K", "8"], [W.INITIAL, W.PLAYER_THIRD]],
]) -> void:
	var pile: Array[String] = []
	pile.assign(codes)
	var windows: Array[BaccaratRound.WindowKind] = BaccaratRoundFixture.play_out(_f.dealt(pile))
	assert_array(windows).contains_exactly(expected)


func test_third_cards_are_drawn_after_their_adjust() -> void:
	var rnd: BaccaratRound = _f.dealt(["2", "K", "3", "4", "5", "6"])
	rnd.proceed()
	rnd.proceed()
	assert_int(rnd.window).is_equal(W.PLAYER_THIRD)
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	rnd.proceed()
	assert_int(rnd.phase).is_equal(BaccaratRound.Phase.ADJUST)
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	rnd.proceed()
	assert_int(rnd.player_hand.cards.size()).is_equal(3)
	assert_int(rnd.window).is_equal(W.BANKER_THIRD)
	assert_int(rnd.banker_hand.cards.size()).is_equal(2)
	rnd.proceed()
	rnd.proceed()
	assert_int(rnd.banker_hand.cards.size()).is_equal(3)
	assert_int(rnd.phase).is_equal(BaccaratRound.Phase.RESOLVED)


func test_a_player_who_stands_takes_no_third_card() -> void:
	var rnd: BaccaratRound = _f.dealt(["3", "2", "3", "3", "K"])
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	assert_int(rnd.banker_hand.cards.size()).is_equal(3)


func test_deal_only_works_once() -> void:
	var rnd: BaccaratRound = _f.dealt(["3", "3", "4", "3", "9", "9"])
	rnd.deal()
	assert_int(rnd.player_hand.cards.size()).is_equal(2)


func test_counts_each_window_opened() -> void:
	var rnd: BaccaratRound = _f.dealt(["2", "A", "3", "A", "A", "A"])
	assert_int(rnd.window_number).is_equal(1)
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.window_number).is_equal(3)
