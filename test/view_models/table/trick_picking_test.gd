extends GdUnitTestSuite
## Picking on the Tricks screen (block U2b): the card being worked on stays
## known through every later step, Ask sits apart from the questions, and a
## partial reveal's answers are tagged on the card for the rest of the hand.
## Blackjack piles deal player 0 and 2, dealer up 1, hole 3 (the 5C), next 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _vm: StackedTableScreenVM


func _deal(questions: int = 1) -> void:
	_vm = StackedTableScreenVM.on(BLACKJACK)
	_vm.setup.choose_game(GameKind.Kind.BLACKJACK)
	_vm.setup.kit.questions_per_reveal = questions
	_vm.sit_down()
	_vm.deal()


func _tags(id: int) -> PackedStringArray:
	for group: CardGroup in _vm.game().card_groups():
		for view: CardView in group.cards:
			if view.id == id:
				return view.tags
	return PackedStringArray()


func _ask(question: PartialQuestion.Kind) -> void:
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	_vm.picker().pick(3)
	_vm.picker().pick(question)


func test_no_card_is_chosen_until_one_is_picked() -> void:
	_deal()
	assert_int(_vm.picker().chosen_card()).is_equal(Card.NO_ID)
	_vm.picker().pick(ActionKind.Kind.PALM)
	assert_int(_vm.picker().chosen_card()).is_equal(Card.NO_ID)


func test_the_chosen_card_stays_through_a_palms_rank_and_suit() -> void:
	_deal()
	var picker: ActionPicker = _vm.picker()
	picker.pick(ActionKind.Kind.PALM)
	picker.pick(2)
	assert_int(picker.chosen_card()).is_equal(2)
	picker.pick(12)
	assert_int(picker.step()).is_equal(ActionPicker.Step.PALM_SUIT)
	assert_int(picker.chosen_card()).is_equal(2)
	picker.pick(Card.Suit.HEARTS)
	assert_int(picker.chosen_card()).is_equal(Card.NO_ID)


func test_a_switchs_first_card_is_chosen_while_the_other_is_picked() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.SWITCH)
	_vm.picker().pick(0)
	assert_int(_vm.picker().chosen_card()).is_equal(0)


func test_one_question_per_reveal_has_no_ask() -> void:
	_deal()
	_vm.picker().pick(ActionKind.Kind.PARTIAL_REVEAL)
	_vm.picker().pick(3)
	assert_bool(_vm.picker().asks_many()).is_false()


func test_ask_sits_apart_from_the_questions() -> void:
	_deal(2)
	var picker: ActionPicker = _vm.picker()
	picker.pick(ActionKind.Kind.PARTIAL_REVEAL)
	picker.pick(3)
	assert_array(StackedTableDebugVM.labels(picker.choices())).contains_exactly(
		["Ten-card?", "Red?"]
	)
	assert_bool(picker.asks_many()).is_true()
	assert_bool(picker.can_ask()).is_false()
	picker.pick(PartialQuestion.Kind.TEN_CARD)
	assert_bool(picker.can_ask()).is_true()
	picker.pick(ActionPicker.ASK)
	assert_int(picker.step()).is_equal(ActionPicker.Step.ACTION)
	assert_bool(picker.asks_many()).is_false()


func test_a_partial_reveal_tags_the_card_with_its_answer() -> void:
	_deal()
	assert_array(_tags(3)).is_empty()
	_ask(PartialQuestion.Kind.TEN_CARD)
	assert_array(_tags(3)).contains_exactly(["TEN? NO"])
	assert_array(_tags(1)).is_empty()


func test_a_second_question_adds_its_tag() -> void:
	_deal()
	_ask(PartialQuestion.Kind.TEN_CARD)
	_ask(PartialQuestion.Kind.RED)
	assert_array(_tags(3)).contains_exactly(["TEN? NO", "RED? NO"])


func test_changing_the_card_drops_its_tags() -> void:
	_deal()
	_ask(PartialQuestion.Kind.TEN_CARD)
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(3)
	_vm.picker().pick(ActionPicker.UP)
	assert_array(_tags(3)).is_empty()


func test_a_new_hand_has_no_tags() -> void:
	_deal()
	_ask(PartialQuestion.Kind.TEN_CARD)
	while _vm.in_hand():
		if _vm.can_proceed():
			_vm.proceed()
		else:
			_vm.play(BlackjackTableVM.Play.STAND)
	_vm.continue_after_hand()
	_vm.deal()
	assert_array(_tags(3)).is_empty()
