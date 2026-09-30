extends GdUnitTestSuite
## What the player has seen this hand feeds side-bet values (spec §8): a
## full reveal or look ahead shows a card, a Palm makes a known card, and a
## Switch moves what the player knows with the card's face.

const STAKE: int = 100

var _f: ActionsFixture
var _rules: SideBetRules


func before_test() -> void:
	_f = ActionsFixture.new()
	_rules = SideBetRules.from_config(_f.config)
	_f.side_bets = [SideBet.new(SideBetKind.Kind.BUST_IT, STAKE)]


## Dealer shows 10; unseen 6 and K. The hole-card window.
func _hand() -> HandActions:
	return _f.actions(_f.blackjack(["10", "10H", "8", "6", "K"]))


func test_nothing_seen_averages_the_hole() -> void:
	var expected: float = 0.5 * STAKE * _rules.bust_it[0] - 0.5 * STAKE
	assert_float(_hand().side_bets_value()).is_equal_approx(expected, 0.001)


func test_a_full_reveal_shows_the_hole() -> void:
	var hand: HandActions = _hand()
	hand.full_reveal(3)
	assert_float(hand.side_bets_value()).is_equal(float(STAKE * _rules.bust_it[0]))


func test_a_palm_makes_a_known_card() -> void:
	var hand: HandActions = _hand()
	hand.palm(3, 13, Card.Suit.SPADES)
	# 10 + K stands on 20.
	assert_float(hand.side_bets_value()).is_equal(float(-STAKE))


func test_a_switch_moves_a_face_up_card_into_the_hole() -> void:
	var hand: HandActions = _hand()
	# The player's 8 goes to the hole: the dealer holds 18 and stands.
	hand.switch_cards(3, 2)
	assert_float(hand.side_bets_value()).is_equal(float(-STAKE))


func _banker(kind: SideBetKind.Kind, codes: Array) -> HandActions:
	_f.side_bets = [SideBet.on_side(kind, STAKE, BaccaratRound.BetSide.BANKER)]
	var pile: Array[String] = []
	pile.assign(codes)
	return _f.actions(_f.baccarat(pile))


func test_a_blind_nudge_keeps_the_believed_face() -> void:
	# The banker shows a 4 and its second card is face down. Nudging it blind
	# changes nothing the player knows, whatever it was.
	var values: Array[float] = []
	for hidden: String in ["3", "5"]:
		var hand: HandActions = _banker(SideBetKind.Kind.PAIR, ["K", "4", "10", hidden, "2", "6"])
		var before: float = hand.side_bets_value()
		hand.nudge(3, 1 if hidden == "3" else -1)
		assert_float(hand.side_bets_value()).is_equal_approx(before, 0.0001)
		values.append(before)
		hand.finish()
	assert_float(values[0]).is_equal_approx(values[1], 0.0001)


func test_a_blind_palm_keeps_the_lost_face_among_the_unseen() -> void:
	# Palm the banker's hidden card into a 3: the player's third card comes
	# from the unseen cards, and the face palmed away is one of them as far
	# as the player knows.
	var values: Array[float] = []
	for pile: Array in [["K", "4", "10", "3", "2", "6"], ["K", "4", "10", "6", "2", "3"]]:
		var hand: HandActions = _banker(SideBetKind.Kind.DRAGON_BONUS, pile)
		hand.palm(3, 3, Card.Suit.HEARTS)
		values.append(hand.side_bets_value())
		hand.finish()
		_f.session.palm_used = false
	assert_float(values[0]).is_equal_approx(values[1], 0.0001)
