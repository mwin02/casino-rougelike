extends GdUnitTestSuite
## The value of a High or Low call (spec §3.3): the remaining cards' odds of
## a win, a tie (half back) and a loss, at the call's actual price.

var _fixture: HighLowRoundFixture = HighLowRoundFixture.new()


func _standard_with_up(up: String) -> HighLowRound:
	var codes: Array[String] = [up]
	for card: Card in Deck.standard(0).cards():
		if card.short_name() != up:
			codes.append(card.short_name())
	var rnd: HighLowRound = _fixture.dealt(codes)
	HighLowRoundFixture.to_call(rnd)
	return rnd


func test_the_value_prices_wins_ties_and_losses() -> void:
	var rnd: HighLowRound = _standard_with_up("AS")
	var remaining: float = rnd.remaining()
	var wins: float = rnd.winners(HighLowRound.Direction.HIGHER)
	var ties: float = remaining - wins - rnd.winners(HighLowRound.Direction.LOWER)
	var expected: float = (
		wins / remaining * rnd.value_if_won(HighLowRound.Direction.HIGHER)
		+ ties / remaining * HighLowRules.tie_value(rnd.chain_value)
		- rnd.chain_value
	)
	assert_float(ties).is_equal(3.0)
	assert_float(HighLowOdds.call_value(rnd, HighLowRound.Direction.HIGHER)).is_equal_approx(
		expected, 1e-6
	)


func test_the_best_direction_is_the_likelier_one() -> void:
	assert_int(HighLowOdds.best_direction(_standard_with_up("2S"))).is_equal(
		HighLowRound.Direction.HIGHER
	)
	assert_int(HighLowOdds.best_direction(_standard_with_up("QS"))).is_equal(
		HighLowRound.Direction.LOWER
	)


func test_a_fairly_priced_call_carries_the_house_edge() -> void:
	# A seven is priced at true odds less the cut either way (no floor or cap
	# binds), so either call is worth about the cut, plus the tie's half loss.
	var rnd: HighLowRound = _standard_with_up("7S")
	var value: float = HighLowOdds.call_value(rnd, HighLowRound.Direction.HIGHER)
	assert_float(value).is_less(0.0)
	assert_float(value).is_greater(-0.15 * rnd.chain_value)
