extends GdUnitTestSuite
## Baccarat win odds from the cards showing (spec §3.2), each unseen card
## drawn with the deck's odds.

var _odds: Array[float] = BaccaratOdds.value_odds(Deck.standard(0).cards())


func test_value_odds_count_tens_and_faces_as_zero() -> void:
	assert_float(_odds[0]).is_equal_approx(16.0 / 52.0, 1e-9)
	assert_float(_odds[1]).is_equal_approx(4.0 / 52.0, 1e-9)
	assert_float(_odds[9]).is_equal_approx(4.0 / 52.0, 1e-9)


func test_nothing_showing_matches_the_known_baccarat_odds() -> void:
	# Infinite-deck baccarat: banker 45.86%, player 44.62%, tie 9.52%.
	var outcomes: Array[float] = BaccaratOdds.outcomes([], [], _odds)
	assert_float(outcomes[BaccaratOdds.PLAYER]).is_equal_approx(0.4462, 0.001)
	assert_float(outcomes[BaccaratOdds.BANKER]).is_equal_approx(0.4586, 0.001)
	assert_float(outcomes[BaccaratOdds.TIE]).is_equal_approx(0.0952, 0.001)


func test_a_natural_settles_at_once() -> void:
	var outcomes: Array[float] = BaccaratOdds.outcomes([9, 0], [4, 3], _odds)
	assert_float(outcomes[BaccaratOdds.PLAYER]).is_equal(1.0)


func test_the_banker_draw_follows_the_tableau() -> void:
	# Player stands on 7; banker 6 stands too when the player stood.
	var outcomes: Array[float] = BaccaratOdds.outcomes([7, 0], [6, 0], _odds)
	assert_float(outcomes[BaccaratOdds.PLAYER]).is_equal(1.0)
	# Player 5 draws; banker 7 always stands: the player wins only on a
	# third card making 8 or 9 (a 3 or a 4).
	var drawn: Array[float] = BaccaratOdds.outcomes([5, 0], [7, 0], _odds)
	assert_float(drawn[BaccaratOdds.PLAYER]).is_equal_approx(8.0 / 52.0, 1e-9)
	assert_float(drawn[BaccaratOdds.TIE]).is_equal_approx(4.0 / 52.0, 1e-9)


func test_side_values_take_the_commission() -> void:
	var rules: BaccaratRules = BaccaratRules.from_config(TuneConfig.load_default())
	var outcomes: Array[float] = [0.4, 0.5, 0.1]
	var commission: float = rules.banker_commission_pct / 100.0
	var player: float = BaccaratOdds.side_value(outcomes, BaccaratRound.BetSide.PLAYER, rules)
	var banker: float = BaccaratOdds.side_value(outcomes, BaccaratRound.BetSide.BANKER, rules)
	assert_float(player).is_equal_approx(-0.1, 1e-9)
	assert_float(banker).is_equal_approx(0.5 * (1.0 - commission) - 0.4, 1e-9)
