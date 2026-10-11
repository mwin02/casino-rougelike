extends GdUnitTestSuite
## The aces-high house rule (spec §3.3): the ace ranks above the king, so the
## extremes are the two and the ace. Pricing is still true odds against the
## remaining cards, so the edge on a standard deck doesn't move.

const RULE: String = "aces_high"
const HIGHER: HighLowRound.Direction = HighLowRound.Direction.HIGHER
const LOWER: HighLowRound.Direction = HighLowRound.Direction.LOWER

var _f: HighLowRoundFixture


func before_test() -> void:
	_f = HighLowRoundFixture.new()


func _under_the_rule() -> void:
	_f.rules = HighLowRules.from_config(_f.config.for_house_rule(RULE))


## A standard deck with one card of rank up dealt first.
func _standard_from(up: int) -> Array[String]:
	var codes: Array[String] = [Card.RANK_CODES[up] + "S"]
	for rank: int in range(1, 14):
		for suit: String in ["S", "H", "D", "C"]:
			if rank != up or suit != "S":
				codes.append(Card.RANK_CODES[rank] + suit)
	return codes


## The best call's expected chain value per unit staked, averaged over every
## first card of a standard deck.
func _single_call_return() -> float:
	var total: float = 0.0
	for up: int in range(1, 14):
		var rnd: HighLowRound = _f.dealt(_standard_from(up))
		var ties: int = rnd.remaining() - rnd.winners(HIGHER) - rnd.winners(LOWER)
		var best: float = 0.0
		for direction: HighLowRound.Direction in [HIGHER, LOWER]:
			var won: float = float(rnd.winners(direction)) * rnd.value_if_won(direction)
			var tied: float = float(ties) * HighLowRules.tie_value(rnd.chain_value)
			best = maxf(best, (won + tied) / rnd.remaining())
		total += best / HighLowRoundFixture.BET
	return total / 13.0


func test_the_ace_ranks_above_the_king_under_the_rule() -> void:
	assert_int(_f.rules.order(1)).is_less(_f.rules.order(2))
	_under_the_rule()
	assert_int(_f.rules.order(1)).is_greater(_f.rules.order(13))
	assert_int(_f.rules.order(2)).is_less(_f.rules.order(3))


func test_higher_on_a_king_has_no_winner_without_the_rule() -> void:
	var rnd: HighLowRound = _f.dealt(["K", "A", "5"])
	assert_int(rnd.winners(HIGHER)).is_equal(0)
	assert_int(rnd.winners(LOWER)).is_equal(2)


func test_higher_on_a_king_wins_with_an_ace_under_the_rule() -> void:
	_under_the_rule()
	var rnd: HighLowRound = _f.dealt(["K", "A", "5"])
	assert_int(rnd.winners(HIGHER)).is_equal(1)
	assert_int(rnd.winners(LOWER)).is_equal(1)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.DECIDE)
	assert_int(rnd.chain_value).is_greater(HighLowRoundFixture.BET)


func test_lower_on_a_king_loses_to_an_ace_under_the_rule() -> void:
	_under_the_rule()
	var rnd: HighLowRound = _f.dealt(["K", "A", "5"])
	HighLowRoundFixture.take(rnd, LOWER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.LOST)


func test_the_ace_is_the_top_extreme_under_the_rule() -> void:
	_under_the_rule()
	var rnd: HighLowRound = _f.dealt(["A", "2", "K", "7"])
	assert_int(rnd.winners(HIGHER)).is_equal(0)
	assert_int(rnd.winners(LOWER)).is_equal(3)


func test_the_two_is_the_bottom_extreme_under_the_rule() -> void:
	_under_the_rule()
	var rnd: HighLowRound = _f.dealt(["2", "A", "K", "7"])
	assert_int(rnd.winners(LOWER)).is_equal(0)
	assert_int(rnd.winners(HIGHER)).is_equal(3)


func test_an_ace_on_an_ace_is_still_a_tie() -> void:
	_under_the_rule()
	var rnd: HighLowRound = _f.dealt(["AS", "AH", "5"])
	HighLowRoundFixture.take(rnd, LOWER)
	assert_int(rnd.outcome).is_equal(HighLowRound.Outcome.TIE)


func test_within_three_ranks_follows_the_order() -> void:
	# §2.5: within three ranks of the card up.
	var ace: Card = Card.parse("A")
	var plain: HighLowRound = _f.dealt(["2", "A", "5"])
	assert_bool(plain.answer(PartialQuestion.Kind.WITHIN_THREE, ace)).is_true()
	var king_up: HighLowRound = _f.dealt(["K", "A", "5"])
	assert_bool(king_up.answer(PartialQuestion.Kind.WITHIN_THREE, ace)).is_false()
	_under_the_rule()
	var ruled: HighLowRound = _f.dealt(["2", "A", "5"])
	assert_bool(ruled.answer(PartialQuestion.Kind.WITHIN_THREE, ace)).is_false()
	var ruled_king: HighLowRound = _f.dealt(["K", "A", "5"])
	assert_bool(ruled_king.answer(PartialQuestion.Kind.WITHIN_THREE, ace)).is_true()


func test_the_single_call_edge_is_the_same_on_a_standard_deck() -> void:
	# Block 17: a house rule never raises the house edge.
	var plain: float = _single_call_return()
	_under_the_rule()
	assert_float(_single_call_return()).is_equal_approx(plain, 1e-9)
	assert_float(plain).is_less(1.0)


func test_a_table_under_the_rule_plays_it() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	fixture.house_rule = RULE
	var session: TableSession = fixture.sit(GameKind.Kind.HIGH_LOW, ["K", "A", "5"])
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	# Calls higher on the king and banks the ace's win.
	assert_int(session.finish_hand().net).is_greater(0)
