extends GdUnitTestSuite
## Cards as the real table draws them: what's face down gives nothing away
## but its mark (spec §2.5), and a taped card wears its tape whenever it's
## face up (§2.3). Blackjack piles deal player, dealer up, player,
## hole, so ids are: player 0 and 2, up card 1, hole card 3, next card 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _fixture: ActionsFixture
var _hand: HandActions


func before_test() -> void:
	_fixture = ActionsFixture.new()
	_fixture.kit.masking_tape = 3


func _blackjack() -> GameTableVM:
	var rnd: BlackjackRound = _fixture.blackjack(BLACKJACK)
	_hand = _fixture.actions(rnd)
	return GameTableVM.for_round(rnd, _fixture.layer)


func _next_blackjack() -> GameTableVM:
	_hand.finish()
	var rnd: BlackjackRound = _fixture.next_blackjack()
	_hand = _fixture.actions(rnd)
	return GameTableVM.for_round(rnd, _fixture.layer)


## The view of card id, wherever it is on the table.
func _card(vm: GameTableVM, id: int) -> CardView:
	for group: CardGroup in vm.card_groups():
		for view: CardView in group.cards:
			if view.id == id:
				return view
	return null


func test_a_face_up_card_shows_its_rank_and_suit() -> void:
	var view: CardView = _card(_blackjack(), 1)
	assert_bool(view.face_down).is_false()
	assert_str(view.rank_text()).is_equal("9")
	assert_int(view.suit).is_equal(Card.Suit.HEARTS)
	assert_bool(view.is_red()).is_true()


func test_a_face_down_card_carries_no_rank_or_suit() -> void:
	var view: CardView = _card(_blackjack(), 3)
	assert_bool(view.face_down).is_true()
	assert_int(view.rank).is_equal(CardView.NO_RANK)
	assert_str(view.rank_text()).is_equal("")
	assert_bool(view.is_red()).is_false()


func test_a_marked_card_shows_its_symbol_face_down() -> void:
	var vm: GameTableVM = _blackjack()
	assert_bool(_card(vm, 3).is_marked()).is_false()
	_hand.mark(3, 1)
	assert_bool(_card(vm, 3).face_down).is_true()
	assert_int(_card(vm, 3).symbol).is_equal(1)


func test_a_change_for_this_hand_only_wears_no_tape() -> void:
	var vm: GameTableVM = _blackjack()
	_hand.nudge(0, -1)
	assert_str(_card(vm, 0).rank_text()).is_equal("Q")
	assert_bool(_card(vm, 0).taped).is_false()


func test_a_taped_card_wears_tape_only_while_face_up() -> void:
	# Spec §2.3: tape on a card's back would mark it for free.
	var vm: GameTableVM = _blackjack()
	_hand.nudge(0, -1)
	_hand.tape(0)
	_hand.nudge(3, 1)
	_hand.tape(3)
	assert_bool(_card(vm, 0).taped).is_true()
	assert_bool(_card(vm, 3).face_down).is_true()
	assert_bool(_card(vm, 3).taped).is_false()
	assert_bool(_card(vm, 1).taped).is_false()


func test_a_taped_hole_card_shows_its_tape_once_it_turns_over() -> void:
	var vm: GameTableVM = _blackjack()
	_hand.nudge(3, 1)
	_hand.tape(3)
	vm.proceed()
	vm.proceed()
	vm.play(BlackjackTableVM.Play.STAND)
	vm.proceed()
	assert_bool(_card(vm, 3).face_down).is_false()
	assert_bool(_card(vm, 3).taped).is_true()


func test_tape_stays_on_for_the_next_hand_of_the_session() -> void:
	_blackjack()
	_hand.nudge(0, -1)
	_hand.tape(0)
	var view: CardView = _card(_next_blackjack(), 0)
	assert_bool(view.taped).is_true()
	assert_str(view.rank_text()).is_equal("Q")


func test_both_cards_of_a_taped_switch_wear_tape() -> void:
	var vm: GameTableVM = _blackjack()
	_hand.switch_cards(0, 1)
	_hand.tape(0)
	assert_bool(_card(vm, 0).taped).is_true()
	assert_bool(_card(vm, 1).taped).is_true()


func test_tape_comes_off_when_the_session_ends() -> void:
	_blackjack()
	_hand.nudge(0, -1)
	_hand.tape(0)
	_hand.finish()
	_fixture.layer.end_session()
	assert_bool(_card(_next_blackjack(), 0).taped).is_false()


func test_a_house_card_never_wears_the_owned_cards_tape() -> void:
	# Spec §7.2: after a house deck swap the table deals the casino's cards.
	var vm: GameTableVM = _blackjack()
	_hand.nudge(0, -1)
	_hand.tape(0)
	var house: Card = Card.new(13, Card.Suit.SPADES)
	house.id = TableSession.HOUSE_ID_BASE
	assert_bool(vm._view(house).taped).is_false()


func test_blackjack_groups_the_dealer_then_each_hand() -> void:
	var groups: Array[CardGroup] = _blackjack().card_groups()
	assert_int(groups.size()).is_equal(2)
	assert_int(groups[0].role).is_equal(CardGroup.Role.DEALER)
	assert_str(groups[0].total_text).is_equal("")
	assert_str(groups[1].label).is_equal("You")
	assert_str(groups[1].total_text).is_equal("17")


func test_baccarat_shows_totals_once_the_second_cards_turn() -> void:
	var rnd: BaccaratRound = _fixture.baccarat(["9S", "2H", "KD", "3C"])
	var vm: GameTableVM = GameTableVM.for_round(rnd, _fixture.layer)
	assert_str(vm.card_groups()[0].total_text).is_equal("")
	assert_bool(vm.card_groups()[1].cards[1].face_down).is_true()
	vm.proceed()
	vm.proceed()
	assert_str(vm.card_groups()[0].total_text).is_equal("9")
	assert_str(vm.card_groups()[1].total_text).is_equal("5")


func test_high_or_low_dims_the_past_and_hides_the_next_card() -> void:
	var rnd: HighLowRound = _fixture.high_low(["5S", "9S", "3S", "KS"])
	var vm: GameTableVM = GameTableVM.for_round(rnd, _fixture.layer)
	var groups: Array[CardGroup] = vm.card_groups()
	assert_array(groups[0].cards).is_empty()
	assert_str(groups[1].cards[0].rank_text()).is_equal("5")
	assert_int(groups[2].role).is_equal(CardGroup.Role.NEXT_CARD)
	assert_bool(groups[2].cards[0].face_down).is_true()
	vm.play(HighLowTableVM.Play.HIGHER)
	vm.play(HighLowTableVM.Play.CONTINUE)
	groups = vm.card_groups()
	assert_bool(groups[0].cards[0].dimmed).is_true()
	assert_str(groups[1].cards[0].rank_text()).is_equal("9")
