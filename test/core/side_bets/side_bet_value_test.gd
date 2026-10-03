extends GdUnitTestSuite
## A side bet's value (spec §8, side-bet heat): its expected net in dollars
## from what the player can see. A card the player can't see is drawn from
## every card of the hand they haven't seen, so its true face never shows.

const STAKE: int = 100
const BANKER: BaccaratRound.BetSide = BaccaratRound.BetSide.BANKER

var _f: ActionsFixture
var _rules: SideBetRules


func before_test() -> void:
	_f = ActionsFixture.new()
	_rules = SideBetRules.from_config(_f.config)


func _only(bet: SideBet) -> void:
	_f.side_bets = [bet]


func _value(rnd: GameRound, known: Array[int] = []) -> float:
	var view: SideBetView = SideBetView.new()
	for id: int in known:
		view.see(id)
	return rnd.side_bet_value(rnd.side_bets[0], view)


func test_face_up_bets_are_worth_their_payout() -> void:
	_only(SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE))
	var rnd: BlackjackRound = _f.blackjack(["7H", "5S", "7D", "9C", "K"])
	assert_float(_value(rnd)).is_equal(float(STAKE * _rules.perfect_pairs[1]))
	rnd = _f.blackjack(["7H", "5S", "8D", "9C", "K"])
	assert_float(_value(rnd)).is_equal(float(-STAKE))


func test_exact_rank_reads_the_card_up() -> void:
	_only(SideBet.exact_rank(STAKE, 9))
	var rnd: HighLowRound = _f.high_low(["9", "2", "3"])
	assert_float(_value(rnd)).is_equal(float(STAKE * _rules.exact_rank))


func test_hidden_pair_card_is_drawn_from_the_unseen_cards() -> void:
	# Banker shows a 4; unseen: 10, 4H, 2, 3. One in four pairs it.
	_only(SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BANKER))
	var rnd: BaccaratRound = _f.baccarat(["K", "4", "10", "4H", "2", "3"])
	var expected: float = 0.25 * STAKE * _rules.pair - 0.75 * STAKE
	assert_float(_value(rnd)).is_equal_approx(expected, 0.001)


func test_a_revealed_card_counts_as_seen() -> void:
	_only(SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BANKER))
	var rnd: BaccaratRound = _f.baccarat(["K", "4", "10", "4H", "2", "3"])
	assert_float(_value(rnd, [3])).is_equal(float(STAKE * _rules.pair))


func test_a_hidden_card_never_leaks_its_face() -> void:
	# Same cards, the banker's hidden second card differs: same value.
	_only(SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BANKER))
	var first: float = _value(_f.baccarat(["K", "4", "10", "4H", "2", "3"]))
	var second: float = _value(_f.baccarat(["K", "4", "10", "2", "4H", "3"]))
	assert_float(second).is_equal_approx(first, 0.001)
	_only(SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, STAKE, BANKER))
	first = _value(_f.baccarat(["3", "6", "K", "6H", "10", "7"]))
	second = _value(_f.baccarat(["3", "6", "10", "7", "K", "6H"]))
	assert_float(second).is_equal_approx(first, 0.001)


func test_dragon_bonus_with_every_card_seen() -> void:
	# Player 3+K draws 10: 3. Banker 6+6 draws 7: 9. Banker by 6.
	_only(SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, STAKE, BANKER))
	var rnd: BaccaratRound = _f.baccarat(["3", "6", "K", "6H", "10", "7"])
	assert_float(_value(rnd, [2, 3, 4, 5])).is_equal(float(STAKE * _rules.dragon_bonus[2]))


func test_bust_it_averages_over_the_hole_card() -> void:
	# Dealer shows 10. Unseen: 6 and K. Hole 6 draws K and busts on three;
	# hole K stands on 20.
	_only(SideBet.new(SideBetKind.Kind.BUST_IT, STAKE))
	var rnd: BlackjackRound = _f.blackjack(["10", "10H", "8", "6", "K"])
	var expected: float = 0.5 * STAKE * _rules.bust_it[0] - 0.5 * STAKE
	assert_float(_value(rnd)).is_equal_approx(expected, 0.001)
	assert_float(_value(rnd, [3])).is_equal(float(STAKE * _rules.bust_it[0]))


func test_bust_it_reads_the_dealers_next_card_in_the_final_window() -> void:
	# Seen hole 6 and next card 5: 21, no bust, though the other unseen
	# cards are all tens.
	_only(SideBet.new(SideBetKind.Kind.BUST_IT, STAKE))
	var rnd: BlackjackRound = _f.blackjack(["10", "10H", "8", "6", "5", "K", "K", "K"])
	rnd.proceed()
	rnd.proceed()
	rnd.stand()
	assert_int(rnd.window).is_equal(BlackjackRound.WindowKind.FINAL)
	assert_float(_value(rnd, [3, 4])).is_equal(float(-STAKE))
	# Before the final window the player may still take that 5, so it counts
	# as unseen.
	var early: BlackjackRound = _f.blackjack(["10", "10H", "8", "6", "5", "K", "K", "K"])
	var unseen_draw: float = 0.75 * STAKE * _rules.bust_it[0] - 0.25 * STAKE
	assert_float(_value(early, [3, 4])).is_equal_approx(unseen_draw, 0.001)


func test_a_settled_bet_is_worth_its_net() -> void:
	_only(SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE))
	var rnd: BlackjackRound = _f.blackjack(["A", "5S", "K", "9C"])
	assert_bool(rnd.is_resolved()).is_true()
	assert_float(_value(rnd)).is_equal(float(-STAKE))


func test_a_face_up_card_wearing_an_unseen_face_is_unknown() -> void:
	# Mid-Switch with the hole card, the player's 8D slot wears the hole's
	# face, which the player hasn't seen. Its value can't tell a 7D from a
	# 2C there: same cards, the face moved differs.
	_only(SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE))
	var values: Array[float] = []
	for face: String in ["7D", "2C"]:
		var other: String = "2C" if face == "7D" else "7D"
		var rnd: BlackjackRound = _f.blackjack(["7H", "5S", face, "9C", other])
		var view: SideBetView = SideBetView.new()
		view.hide(2)
		values.append(rnd.side_bet_value(rnd.side_bets[0], view))
	assert_float(values[0]).is_equal_approx(values[1], 0.001)
	# Unseen: that face, the hole, and the next card; one in three pairs it.
	var expected: float = STAKE * _rules.perfect_pairs[1] / 3.0 - STAKE * 2.0 / 3.0
	assert_float(values[0]).is_equal_approx(expected, 0.001)
