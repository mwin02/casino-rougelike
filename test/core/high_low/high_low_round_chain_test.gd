extends GdUnitTestSuite
## A chain draws without replacement from one pile (spec §3.3, §4.1): no
## reshuffle within a chain. Calls are priced against the owned deck minus the
## cards drawn this chain; temporary manipulation isn't priced in, while the
## call itself is decided by the cards as they read.

const HIGHER: HighLowRound.Direction = HighLowRound.Direction.HIGHER
const LOWER: HighLowRound.Direction = HighLowRound.Direction.LOWER
const BET: int = HighLowRoundFixture.BET

var _f: HighLowRoundFixture


func before_test() -> void:
	_f = HighLowRoundFixture.new()


func test_no_reshuffle_within_a_chain() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "9S", "3S", "KS", "7S"])
	assert_int(rnd.remaining()).is_equal(4)
	# 9, 3, K, 7 remain: three beat the 5, one is under it.
	assert_int(rnd.winners(HIGHER)).is_equal(3)
	assert_int(rnd.winners(LOWER)).is_equal(1)
	HighLowRoundFixture.take(rnd, HIGHER)
	HighLowRoundFixture.take(rnd, LOWER)
	var drawn: Array[String] = []
	for card: Card in rnd.cards:
		drawn.append(card.short_name())
	assert_array(drawn).contains_exactly(["5S", "9S", "3S"])
	# K and 7 remain; both beat the 3.
	assert_int(rnd.remaining()).is_equal(2)
	assert_int(rnd.winners(HIGHER)).is_equal(2)
	assert_int(rnd.winners(LOWER)).is_equal(0)


func test_ties_are_neither_higher_nor_lower() -> void:
	var rnd: HighLowRound = _f.dealt(["5S", "5H", "9S", "3S"])
	assert_int(rnd.remaining()).is_equal(3)
	assert_int(rnd.winners(HIGHER)).is_equal(1)
	assert_int(rnd.winners(LOWER)).is_equal(1)


func test_aces_are_low() -> void:
	var rnd: HighLowRound = _f.dealt(["AS", "2S", "KS"])
	assert_int(rnd.winners(HIGHER)).is_equal(2)
	assert_int(rnd.winners(LOWER)).is_equal(0)


func test_calls_are_priced_against_the_owned_deck() -> void:
	_f.build_deck(["5S", "2S", "3S", "KS"])
	# A Nudge-style change for this hand: the 2 (id 1) reads as a 6.
	_f.layer.change(1, 6, Card.Suit.SPADES)
	var rnd: HighLowRound = _f.new_round()
	rnd.deal()
	# Owned 2, 3, K remain: only the K beats the 5.
	assert_int(rnd.winners(HIGHER)).is_equal(1)
	HighLowRoundFixture.take(rnd, HIGHER)
	# The 6 is dealt and wins; priced 1 of 3, 3 × 93 / 100 = ×2.79.
	assert_str(rnd.current().short_name()).is_equal("6S")
	assert_int(rnd.chain_value).is_equal(2790)
	# Owned 3, K remain; the K beats the 6 as it reads.
	assert_int(rnd.winners(HIGHER)).is_equal(1)
	assert_int(rnd.winners(LOWER)).is_equal(1)


func test_a_call_with_no_winners_won_by_a_changed_card_pays_the_cap() -> void:
	_f.build_deck(["9S", "2S", "3S", "4S"])
	# A Palm-style change: the 2 (id 1) reads as a King.
	_f.layer.change(1, 13, Card.Suit.SPADES)
	var rnd: HighLowRound = _f.new_round()
	rnd.deal()
	assert_int(rnd.winners(HIGHER)).is_equal(0)
	HighLowRoundFixture.take(rnd, HIGHER)
	assert_int(rnd.phase).is_equal(HighLowRound.Phase.DECIDE)
	assert_int(rnd.chain_value).is_equal(BET * _f.rules.max_call_payout_pct / 100)
