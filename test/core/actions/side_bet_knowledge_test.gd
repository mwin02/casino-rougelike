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
