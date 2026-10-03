extends GdUnitTestSuite
## Side bets ride a round (spec §8): placed before the deal only, never moved
## by an adjust, and settled at resolution on the cards as they read then.

const K: SideBetKind.Kind = SideBetKind.Kind.PERFECT_PAIRS
const BANKER: BaccaratRound.BetSide = BaccaratRound.BetSide.BANKER
const STAKE: int = 100

var _config: TuneConfig = TuneConfig.load_default()
var _rules: SideBetRules = SideBetRules.from_config(_config)


func _pile(codes: Array[String]) -> Array[Card]:
	var pile: Array[Card] = []
	for code: String in codes:
		var card: Card = Card.parse(code)
		card.id = pile.size()
		pile.append(card)
	return pile


## A blackjack round with bets placed, dealt.
func _blackjack(codes: Array[String], bets: Array[SideBet]) -> BlackjackRound:
	var limits: BetLimits = BetLimits.from_config(_config, 1000, 100, 100000)
	var rnd: BlackjackRound = BlackjackRound.new(
		BlackjackRules.from_config(_config), limits, _pile(codes)
	)
	assert_bool(rnd.place_side_bets(_rules, bets)).is_true()
	rnd.deal()
	return rnd


func _baccarat(codes: Array[String], bets: Array[SideBet]) -> BaccaratRound:
	var limits: BetLimits = BetLimits.from_config(_config, 1000, 100, 100000)
	var rnd: BaccaratRound = BaccaratRound.new(
		BaccaratRules.from_config(_config), BaccaratRound.BetSide.PLAYER, limits, _pile(codes)
	)
	assert_bool(rnd.place_side_bets(_rules, bets)).is_true()
	rnd.deal()
	return rnd


func _bet(kind: SideBetKind.Kind) -> Array[SideBet]:
	return [SideBet.new(kind, STAKE)]


func _stand_out(rnd: BlackjackRound) -> void:
	rnd.proceed()
	rnd.proceed()
	rnd.stand()
	rnd.proceed()


func test_side_bets_are_placed_before_the_deal_only() -> void:
	var rnd: BlackjackRound = _blackjack(["7H", "5S", "7D", "9C"], [])
	assert_bool(rnd.place_side_bets(_rules, _bet(K))).is_false()
	assert_array(rnd.side_bets).is_empty()


func test_perfect_pairs_settles_at_resolution() -> void:
	var rnd: BlackjackRound = _blackjack(["7H", "5S", "7D", "9C", "K"], _bet(K))
	assert_bool(rnd.side_bets[0].is_settled()).is_false()
	_stand_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.perfect_pairs[1])
	assert_int(rnd.side_net()).is_equal(STAKE * _rules.perfect_pairs[1])


func test_side_bets_read_the_cards_as_manipulated() -> void:
	# Manipulation is priced by heat (block 10 PR 4), not ignored.
	var rnd: BlackjackRound = _blackjack(["7H", "5S", "8D", "9C", "K"], _bet(K))
	rnd.rewrite_card(2, 7, Card.Suit.DIAMONDS)
	_stand_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.perfect_pairs[1])


func test_twenty_one_plus_three_reads_the_up_card() -> void:
	var bets: Array[SideBet] = _bet(SideBetKind.Kind.TWENTY_ONE_PLUS_THREE)
	var rnd: BlackjackRound = _blackjack(["5H", "7H", "6H", "9C", "K"], bets)
	_stand_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.twenty_one_plus_three[0])


func test_perfect_pairs_keeps_the_first_two_cards_after_a_split() -> void:
	var rnd: BlackjackRound = _blackjack(["8H", "5S", "8D", "9C", "2", "3", "K"], _bet(K))
	rnd.proceed()
	rnd.proceed()
	rnd.split()
	rnd.stand()
	rnd.stand()
	rnd.proceed()
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.perfect_pairs[1])


func test_bust_it_pays_by_dealer_cards() -> void:
	# Dealer 10 + 6, draws K: bust on 3 cards.
	var bets: Array[SideBet] = _bet(SideBetKind.Kind.BUST_IT)
	var rnd: BlackjackRound = _blackjack(["10", "10H", "8", "6", "K"], bets)
	_stand_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.bust_it[0])


func test_bust_it_draws_the_dealer_out_after_a_player_natural() -> void:
	var bets: Array[SideBet] = _bet(SideBetKind.Kind.BUST_IT)
	var rnd: BlackjackRound = _blackjack(["A", "10H", "K", "6", "K"], bets)
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(rnd.hands[0].outcome).is_equal(BlackjackHand.Outcome.NATURAL)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(3)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.bust_it[0])


func test_bust_it_draws_the_dealer_out_after_every_hand_busts() -> void:
	var bets: Array[SideBet] = _bet(SideBetKind.Kind.BUST_IT)
	var rnd: BlackjackRound = _blackjack(["10", "10H", "6", "6", "K", "Q"], bets)
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	rnd.proceed()
	rnd.proceed()
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(rnd.hands[0].outcome).is_equal(BlackjackHand.Outcome.PLAYER_BUST)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.bust_it[0])


func test_without_bust_it_the_dealer_stays_put() -> void:
	var rnd: BlackjackRound = _blackjack(["A", "10H", "K", "6", "K"], _bet(K))
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)


func test_an_adjust_never_moves_a_side_bet() -> void:
	var rnd: BlackjackRound = _blackjack(["7H", "5S", "8D", "9C", "K"], _bet(K))
	rnd.proceed()
	rnd.adjust(2000)
	assert_int(rnd.total_bet()).is_equal(2000)
	assert_int(rnd.side_bets[0].stake).is_equal(STAKE)


func test_dragon_bonus_on_banker_pays_the_margin() -> void:
	# Player K+10 = 0 draws a K (0); banker 4+5 = 9 is a natural.
	var bets: Array[SideBet] = [SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, STAKE, BANKER)]
	var rnd: BaccaratRound = _baccarat(["K", "4", "10", "5"], bets)
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.dragon_natural)


func test_dragon_bonus_non_natural_margin() -> void:
	# Player 3+K = 3 draws 10 (3); banker 6+6 = 2 draws 7: 9. Banker by 6.
	var bets: Array[SideBet] = [SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, STAKE, BANKER)]
	var rnd: BaccaratRound = _baccarat(["3", "6", "K", "6H", "10", "7"], bets)
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.banker_hand.total() - rnd.player_hand.total()).is_equal(6)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.dragon_bonus[2])


func test_pair_reads_its_own_side() -> void:
	var bets: Array[SideBet] = [
		SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BANKER),
		SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BaccaratRound.BetSide.PLAYER),
	]
	var rnd: BaccaratRound = _baccarat(["K", "4", "10", "4H", "2", "2"], bets)
	BaccaratRoundFixture.play_out(rnd)
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.pair)
	assert_int(rnd.side_bets[1].pays).is_equal(SideBetPayout.LOSE)


func test_exact_rank_reads_the_first_card_up() -> void:
	var fixture: HighLowRoundFixture = HighLowRoundFixture.new()
	fixture.build_deck(["Q", "2", "3", "4"])
	var rnd: HighLowRound = fixture.new_round()
	assert_bool(rnd.place_side_bets(_rules, [SideBet.exact_rank(STAKE, 12)])).is_true()
	rnd.deal()
	HighLowRoundFixture.to_call(rnd)
	rnd.call_next(HighLowRound.Direction.LOWER)
	assert_bool(rnd.side_bets[0].is_settled()).is_false()
	rnd.bank()
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(rnd.side_bets[0].pays).is_equal(_rules.exact_rank)
