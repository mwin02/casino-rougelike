extends GdUnitTestSuite
## One blackjack round: deal, hit, stand, resolve. Piles are dealt in order:
## player, dealer up, player, dealer hole, then hits (player first, then dealer).

const BET: int = 1000

var _rules: BlackjackRules


func before_test() -> void:
	_rules = BlackjackRules.from_config(TuneConfig.load_default())


func _round(codes: Array[String]) -> BlackjackRound:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	var rnd: BlackjackRound = BlackjackRound.new(_rules, BET, pile)
	rnd.deal()
	return rnd


func test_deal_gives_two_cards_each_in_order() -> void:
	var rnd: BlackjackRound = _round(["2", "3", "4", "5"])
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.player_hand.total()).is_equal(6)
	assert_int(rnd.dealer_hand.total()).is_equal(8)
	assert_int(rnd.state).is_equal(BlackjackRound.State.PLAYER_TURN)


func test_hit_adds_a_card() -> void:
	var rnd: BlackjackRound = _round(["2", "K", "3", "7", "4"])
	rnd.hit()
	assert_int(rnd.player_hand.total()).is_equal(9)
	assert_int(rnd.state).is_equal(BlackjackRound.State.PLAYER_TURN)


func test_dealer_hits_soft_17() -> void:
	# Dealer A+6 is soft 17: hits, draws 4 for soft 21, stands.
	var rnd: BlackjackRound = _round(["K", "A", "Q", "6", "4"])
	rnd.stand()
	assert_int(rnd.dealer_hand.cards.size()).is_equal(3)
	assert_int(rnd.dealer_hand.total()).is_equal(21)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.LOSE)


func test_dealer_stands_on_soft_17_when_rule_off() -> void:
	_rules.dealer_hits_soft_17 = false
	var rnd: BlackjackRound = _round(["K", "A", "Q", "6", "4"])
	rnd.stand()
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.WIN)


func test_dealer_stands_on_hard_17() -> void:
	var rnd: BlackjackRound = _round(["K", "10", "Q", "7", "4"])
	rnd.stand()
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.WIN)


func test_dealer_stands_on_soft_18() -> void:
	var rnd: BlackjackRound = _round(["K", "A", "9", "7", "4"])
	rnd.stand()
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.WIN)


func test_dealer_keeps_hitting_below_17() -> void:
	# 16, then A makes hard 17 (A as 11 would be 27).
	var rnd: BlackjackRound = _round(["K", "10", "Q", "6", "A"])
	rnd.stand()
	assert_int(rnd.dealer_hand.total()).is_equal(17)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.WIN)


func test_dealer_does_not_play_after_player_busts() -> void:
	var rnd: BlackjackRound = _round(["K", "10", "Q", "6", "5"])
	rnd.hit()
	assert_int(rnd.state).is_equal(BlackjackRound.State.RESOLVED)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.PLAYER_BUST)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(rnd.net()).is_equal(-BET)


func test_player_at_22_is_not_bust() -> void:
	var rnd: BlackjackRound = _round(["K", "10", "Q", "8", "2"])
	rnd.hit()
	assert_int(rnd.state).is_equal(BlackjackRound.State.PLAYER_TURN)
	rnd.stand()
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.WIN)


func test_natural_pays_configured_payout() -> void:
	var rnd: BlackjackRound = _round(["A", "9", "K", "7"])
	assert_int(rnd.state).is_equal(BlackjackRound.State.RESOLVED)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.NATURAL)
	var expected: int = Money.apply_ratio(BET, _rules.natural_payout_num, _rules.natural_payout_den)
	assert_int(rnd.net()).is_equal(expected)


func test_natural_pays_3_to_2_by_default() -> void:
	# Spec §3.1: blackjack pays 3:2 unless a floor signature changes it.
	var rnd: BlackjackRound = _round(["A", "9", "K", "7"])
	assert_int(rnd.net()).is_equal(1500)


func test_natural_pays_6_to_5_when_configured() -> void:
	# Floor 3's stingy-house signature (spec §5.3).
	_rules.natural_payout_num = 6
	_rules.natural_payout_den = 5
	var rnd: BlackjackRound = _round(["A", "9", "K", "7"])
	assert_int(rnd.net()).is_equal(1200)


func test_natural_against_natural_pushes() -> void:
	var rnd: BlackjackRound = _round(["A", "A", "K", "Q"])
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.PUSH)
	assert_int(rnd.net()).is_equal(0)


func test_dealer_natural_beats_player_22() -> void:
	var rnd: BlackjackRound = _round(["K", "A", "Q", "K", "2"])
	rnd.hit()
	rnd.stand()
	assert_int(rnd.player_hand.total()).is_equal(22)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.LOSE)


func test_equal_totals_push() -> void:
	var rnd: BlackjackRound = _round(["K", "10", "8", "8"])
	rnd.stand()
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.PUSH)
	assert_int(rnd.net()).is_equal(0)


func test_lower_total_loses() -> void:
	var rnd: BlackjackRound = _round(["K", "10", "7", "9"])
	rnd.stand()
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.LOSE)
	assert_int(rnd.net()).is_equal(-BET)


func test_dealer_bust_pays_even_money() -> void:
	# Dealer 16 draws K: 26.
	var rnd: BlackjackRound = _round(["K", "10", "2", "6", "K"])
	rnd.stand()
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.DEALER_BUST)
	assert_int(rnd.net()).is_equal(BET)


func test_actions_ignored_after_resolution() -> void:
	var rnd: BlackjackRound = _round(["A", "9", "K", "7", "5"])
	rnd.hit()
	rnd.stand()
	assert_int(rnd.player_hand.cards.size()).is_equal(2)
	assert_int(rnd.outcome).is_equal(BlackjackRound.Outcome.NATURAL)
