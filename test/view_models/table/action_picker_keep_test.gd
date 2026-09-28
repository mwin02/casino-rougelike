extends GdUnitTestSuite
## Keeping a change (spec §2.3, §9): Masking Tape, a Cold Seal or an Ink
## charge on a card changed this hand. And the Loaded Question hook (§9):
## a partial reveal that asks more than one question. Blackjack piles deal
## player 0 and 2, dealer up 1, hole 3, next 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _fixture: ActionsFixture
var _hand: HandActions
var _picker: ActionPicker


func before_test() -> void:
	_fixture = ActionsFixture.new()
	_fixture.kit.masking_tape = 2
	_fixture.kit.cold_seals = 1
	_hand = _fixture.actions(_fixture.blackjack(BLACKJACK))
	_picker = ActionPicker.new(_hand, _fixture.kit, _code, true)


func _code(card: Card) -> String:
	return card.short_name()


func _labels(choices: Array[Choice]) -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in choices:
		labels.append(choice.label)
	return labels


func _choice(choices: Array[Choice], label: String) -> Choice:
	for choice: Choice in choices:
		if choice.label == label:
			return choice
	fail("no choice labelled " + label)
	return null


func _pick(label: String) -> void:
	_picker.pick(_choice(_picker.choices(), label).id)


func _keep(label: String) -> void:
	_picker.keep(_choice(_picker.keep_choices(), label).id)


func test_nothing_to_keep_before_a_manipulation() -> void:
	assert_array(_picker.keep_choices()).is_empty()


func test_each_changed_card_offers_every_consumable_with_its_count() -> void:
	_hand.nudge(2, 1)
	var choices: Array[Choice] = _picker.keep_choices()
	assert_array(_labels(choices)).contains_exactly(["Tape 8D (2)", "Seal 8D (1)", "Ink 8D (0)"])
	assert_bool(_choice(choices, "Ink 8D (0)").enabled).is_false()


func test_tape_keeps_the_change_for_the_session() -> void:
	_hand.nudge(2, 1)
	_keep("Tape 8D (2)")
	assert_array(_picker.info_lines).contains_exactly(["8D taped"])
	assert_bool(_fixture.layer.is_taped(2)).is_true()
	assert_int(_fixture.kit.masking_tape).is_equal(1)
	assert_array(_picker.keep_choices()).is_empty()


func test_seal_writes_the_change_into_the_deck() -> void:
	_hand.nudge(2, 1)
	_keep("Seal 8D (1)")
	assert_array(_picker.info_lines).contains_exactly(["8D sealed"])
	assert_str(_fixture.deck.card(2).short_name()).is_equal("8D")


func test_ink_makes_the_change_permanent() -> void:
	_fixture.kit.ink_charges = 1
	_hand.nudge(2, 1)
	_keep("Ink 8D (1)")
	assert_array(_picker.info_lines).contains_exactly(["8D inked"])
	assert_int(_fixture.kit.ink_charges).is_equal(0)


func test_keeping_a_switch_names_both_cards() -> void:
	_hand.switch_cards(2, 3)
	_keep("Seal 5C (1)")
	assert_array(_picker.info_lines).contains_exactly(["5C and 7D sealed"])


func test_a_refused_keep_is_logged() -> void:
	_hand.nudge(2, 1)
	var id: int = _choice(_picker.keep_choices(), "Seal 8D (1)").id
	_fixture.kit.cold_seals = 0
	_picker.keep(id)
	assert_array(_picker.info_lines).contains_exactly(["Seal refused"])


func test_one_question_per_reveal_asks_at_once() -> void:
	_pick("Partial reveal 2")
	_pick("5C")
	assert_array(_labels(_picker.choices())).contains_exactly(["Ten-card?", "Red?"])


func test_loaded_question_picks_up_to_two_then_asks() -> void:
	_fixture.kit.questions_per_reveal = 2
	_pick("Partial reveal 2")
	_pick("5C")
	assert_array(_labels(_picker.choices())).contains_exactly(["[ ] Ten-card?", "[ ] Red?", "Ask"])
	assert_bool(_choice(_picker.choices(), "Ask").enabled).is_false()
	_pick("[ ] Ten-card?")
	_pick("[ ] Red?")
	assert_array(_labels(_picker.choices())).contains_exactly(["[x] Ten-card?", "[x] Red?", "Ask"])
	_pick("Ask")
	assert_array(_picker.info_lines).contains_exactly(["5C: ten-card? no, red? no"])
	assert_int(_hand.used.size()).is_equal(1)


func test_loaded_question_can_unpick_a_question() -> void:
	_fixture.kit.questions_per_reveal = 2
	_pick("Partial reveal 2")
	_pick("5C")
	_pick("[ ] Red?")
	_pick("[x] Red?")
	assert_bool(_choice(_picker.choices(), "Ask").enabled).is_false()
