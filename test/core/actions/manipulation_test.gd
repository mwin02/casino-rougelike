extends GdUnitTestSuite
## Manipulation (spec §2.3): Nudge ±1 rank without wrapping, Recolour, Switch
## and Palm, on any card in play. Card i has id i.

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


## Hole-card window: player 0 and 2, dealer up 1, hole 3.
func _table(hole: String = "7H") -> BlackjackRound:
	return _f.blackjack(["10", "9", "6", hole, "5"])


func test_nudge_moves_one_rank_either_way() -> void:
	var rnd: BlackjackRound = _table()
	var actions: HandActions = _f.actions(rnd)
	assert_bool(actions.nudge(3, 1)).is_true()
	assert_int(rnd.dealer_hand.cards[1].rank).is_equal(8)
	assert_bool(actions.nudge(3, -1)).is_true()
	assert_bool(actions.nudge(3, -1)).is_true()
	assert_int(rnd.dealer_hand.cards[1].rank).is_equal(6)


func test_nudge_does_not_wrap_a_king_up() -> void:
	var rnd: BlackjackRound = _table("KS")
	assert_bool(_f.actions(rnd).nudge(3, 1)).is_false()
	assert_int(rnd.dealer_hand.cards[1].rank).is_equal(13)


func test_nudge_does_not_wrap_an_ace_down() -> void:
	var rnd: BlackjackRound = _table("AS")
	assert_bool(_f.actions(rnd).nudge(3, -1)).is_false()
	assert_int(rnd.dealer_hand.cards[1].rank).is_equal(1)


func test_nudge_moves_only_one_rank() -> void:
	var rnd: BlackjackRound = _table()
	assert_bool(_f.actions(rnd).nudge(3, 2)).is_false()
	assert_bool(_f.actions(rnd).nudge(3, 0)).is_false()


func test_nudge_reaches_a_face_up_card_in_play() -> void:
	var rnd: BlackjackRound = _table()
	assert_bool(_f.actions(rnd).nudge(2, -1)).is_true()
	assert_int(rnd.hands[0].total()).is_equal(15)


func test_recolour_changes_the_suit() -> void:
	var rnd: BlackjackRound = _table("7H")
	var actions: HandActions = _f.actions(rnd)
	assert_bool(actions.recolour(3, Card.Suit.SPADES)).is_true()
	assert_str(rnd.dealer_hand.cards[1].short_name()).is_equal("7S")
	assert_bool(actions.recolour(3, Card.Suit.SPADES)).is_false()


func test_switch_trades_identities_and_marks_stay_put() -> void:
	var rnd: BlackjackRound = _table("7H")
	var actions: HandActions = _f.actions(rnd)
	actions.mark(3, 1)
	assert_bool(actions.switch_cards(3, 0)).is_true()
	var hole: Card = rnd.dealer_hand.cards[1]
	var first: Card = rnd.hands[0].cards[0]
	assert_str(hole.short_name()).is_equal("10S")
	assert_str(first.short_name()).is_equal("7H")
	assert_int(hole.symbol).is_equal(1)
	assert_bool(first.is_marked()).is_false()


func test_switch_needs_two_cards_in_play() -> void:
	var rnd: BlackjackRound = _table()
	var actions: HandActions = _f.actions(rnd)
	assert_bool(actions.switch_cards(3, 3)).is_false()
	assert_bool(actions.switch_cards(3, 4)).is_false()


func test_palm_turns_a_card_into_any_card() -> void:
	var rnd: BlackjackRound = _table()
	assert_bool(_f.actions(rnd).palm(3, 1, Card.Suit.CLUBS)).is_true()
	assert_str(rnd.dealer_hand.cards[1].short_name()).is_equal("AC")


func test_palm_once_per_session() -> void:
	var rnd: BlackjackRound = _table()
	var actions: HandActions = _f.actions(rnd)
	actions.palm(3, 1, Card.Suit.CLUBS)
	assert_bool(actions.palm(2, 1, Card.Suit.HEARTS)).is_false()
	actions.finish()
	var next: BlackjackRound = _f.next_blackjack()
	assert_bool(_f.actions(next).can_use(ActionKind.Kind.PALM)).is_false()
	_f.session = ActionSession.new()
	assert_bool(_f.actions(next).can_use(ActionKind.Kind.PALM)).is_true()


func test_only_cards_in_play() -> void:
	var rnd: BlackjackRound = _table()
	assert_bool(_f.actions(rnd).nudge(4, 1)).is_false()


func test_needs_the_action_unlocked() -> void:
	_f.kit = ActionKit.starting()
	var rnd: BlackjackRound = _table()
	var actions: HandActions = _f.actions(rnd)
	assert_bool(actions.recolour(3, Card.Suit.SPADES)).is_false()
	assert_bool(actions.nudge(3, 1)).is_true()


func test_recorded_with_its_window() -> void:
	var rnd: BlackjackRound = _table()
	var actions: HandActions = _f.actions(rnd)
	actions.switch_cards(3, 0)
	assert_int(actions.used[0].action).is_equal(ActionKind.Kind.SWITCH)
	assert_int(actions.used[0].window_number).is_equal(1)
	assert_array(actions.used[0].card_ids).contains_exactly([3, 0])


func test_works_in_baccarat_and_high_low() -> void:
	var bac: BaccaratRound = _f.baccarat(["2", "A", "3", "A"])
	assert_bool(_f.actions(bac).nudge(2, 1)).is_true()
	assert_int(bac.player_hand.total()).is_equal(6)
	var hilo: HighLowRound = _f.high_low(["5", "9"])
	assert_bool(_f.actions(hilo).nudge(0, 1)).is_true()
	assert_int(hilo.current().rank).is_equal(6)
