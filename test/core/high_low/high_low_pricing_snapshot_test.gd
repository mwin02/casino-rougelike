extends GdUnitTestSuite
## High or Low prices calls against the owned deck as it stood when the table
## session began (spec §3.3). A card sealed mid-session keeps its old price
## until the next session, so the change is the player's edge meanwhile.
## Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()
	_f.kit.cold_seals = 1


func test_a_card_sealed_mid_chain_keeps_its_price() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "2", "3"])
	var before: int = rnd.winners(HighLowRound.Direction.HIGHER)
	var actions: HandActions = _f.actions(rnd)
	actions.palm(1, 4, Card.Suit.SPADES)
	assert_bool(actions.seal(1)).is_true()
	assert_int(_f.deck.card(1).rank).is_equal(4)
	assert_int(rnd.winners(HighLowRound.Direction.HIGHER)).is_equal(before)
