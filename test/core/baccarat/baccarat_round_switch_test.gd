extends GdUnitTestSuite
## Switching sides (spec §3.2): Player ↔ Banker in any adjust, recorded as a
## bet change every time. Tie never switches. A locked bet can't switch (§2.2).

## Player 5 and banker 4 both draw, so the round has three adjusts.
const THREE_ADJUSTS: Array[String] = ["2", "K", "3", "4", "5", "6"]

var _f: BaccaratRoundFixture


func before_test() -> void:
	_f = BaccaratRoundFixture.new()


func _at_adjust(side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER) -> BaccaratRound:
	var rnd: BaccaratRound = _f.dealt(THREE_ADJUSTS, side)
	rnd.proceed()
	return rnd


func test_switching_only_in_an_adjust() -> void:
	var rnd: BaccaratRound = _f.dealt(THREE_ADJUSTS)
	assert_bool(rnd.can_switch_side()).is_false()
	rnd.switch_side()
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.PLAYER)
	rnd.proceed()
	assert_bool(rnd.can_switch_side()).is_true()


func test_a_switch_is_recorded_as_a_bet_change() -> void:
	var rnd: BaccaratRound = _at_adjust()
	rnd.switch_side()
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.BANKER)
	assert_int(rnd.bet_changes.size()).is_equal(1)
	var change: BetChange = rnd.bet_changes[0]
	assert_int(change.kind).is_equal(BetChange.Kind.SIDE_SWITCH)
	assert_int(change.amount).is_equal(0)
	assert_int(change.hand_index).is_equal(BetChange.NO_HAND)
	assert_int(rnd.stake).is_equal(BaccaratRoundFixture.BET)


func test_switching_back_is_a_second_change() -> void:
	var rnd: BaccaratRound = _at_adjust(BaccaratRound.BetSide.BANKER)
	rnd.switch_side()
	rnd.switch_side()
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.BANKER)
	assert_int(rnd.bet_changes.size()).is_equal(2)


func test_switching_in_the_third_card_adjusts() -> void:
	var rnd: BaccaratRound = _at_adjust()
	rnd.proceed()
	assert_int(rnd.window).is_equal(BaccaratRound.WindowKind.PLAYER_THIRD)
	assert_bool(rnd.can_switch_side()).is_false()
	rnd.proceed()
	rnd.switch_side()
	rnd.proceed()
	assert_int(rnd.window).is_equal(BaccaratRound.WindowKind.BANKER_THIRD)
	rnd.proceed()
	rnd.switch_side()
	assert_int(rnd.bet_changes.size()).is_equal(2)
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.PLAYER)


func test_a_tie_bet_never_switches() -> void:
	var rnd: BaccaratRound = _at_adjust(BaccaratRound.BetSide.TIE)
	assert_bool(rnd.can_switch_side()).is_false()
	rnd.switch_side()
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.TIE)
	assert_array(rnd.bet_changes).is_empty()


func test_a_locked_bet_cannot_switch() -> void:
	var rnd: BaccaratRound = _at_adjust()
	rnd.lock_bet()
	assert_bool(rnd.is_bet_locked()).is_true()
	assert_bool(rnd.can_switch_side()).is_false()
	rnd.switch_side()
	assert_int(rnd.side).is_equal(BaccaratRound.BetSide.PLAYER)
	assert_array(rnd.bet_changes).is_empty()


func test_no_switching_once_resolved() -> void:
	var rnd: BaccaratRound = _at_adjust()
	BaccaratRoundFixture.play_out(rnd)
	assert_bool(rnd.can_switch_side()).is_false()


func test_a_switch_is_ahead_in_a_window_an_adjust_follows() -> void:
	var rnd: BaccaratRound = _f.dealt(THREE_ADJUSTS)
	assert_bool(rnd.switch_side_ahead()).is_true()
	rnd.proceed()
	assert_bool(rnd.switch_side_ahead()).is_true()
	rnd.proceed()
	assert_bool(rnd.switch_side_ahead()).is_true()
	rnd.lock_bet()
	assert_bool(rnd.switch_side_ahead()).is_false()


func test_no_switch_is_ahead_for_a_tie_bet() -> void:
	var rnd: BaccaratRound = _f.dealt(THREE_ADJUSTS, BaccaratRound.BetSide.TIE)
	assert_bool(rnd.switch_side_ahead()).is_false()
