extends GdUnitTestSuite
## Partial reveal (spec §2.5): each game's yes/no questions, answered by the
## card as it reads now. Card i has id i.

const Q := PartialQuestion.Kind

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func _ask(actions: HandActions, card_id: int, question: PartialQuestion.Kind) -> Array[bool]:
	var asked: Array[PartialQuestion.Kind] = [question]
	return actions.partial_reveal(card_id, asked)


## Player 10+6 = 16, in the window before a hit on incoming.
func _before_hit(incoming: String) -> BlackjackRound:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", incoming])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	return rnd


# gdlint: ignore=unused-argument
func test_blackjack_busts_me(incoming: String, busts: bool, test_parameters: Array = [
	["6", true],  # 22: bust at the default threshold (§3.1)
	["5", false],  # 21
	["K", true],
	["A", false],  # 17
]) -> void:
	var rnd: BlackjackRound = _before_hit(incoming)
	assert_array(_ask(_f.actions(rnd), 4, Q.BUSTS_ME)).contains_exactly([busts])


# gdlint: ignore=unused-argument
func test_blackjack_ten_card(hole: String, ten: bool, test_parameters: Array = [
	["10", true],
	["J", true],
	["K", true],
	["9", false],
	["A", false],
]) -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", hole])
	assert_array(_ask(_f.actions(rnd), 3, Q.TEN_CARD)).contains_exactly([ten])


# gdlint: ignore=unused-argument
func test_blackjack_red(hole: String, red: bool, test_parameters: Array = [
	["5H", true],
	["5D", true],
	["5S", false],
	["5C", false],
]) -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", hole])
	assert_array(_ask(_f.actions(rnd), 3, Q.RED)).contains_exactly([red])


func test_blackjack_busts_me_only_on_the_incoming_card() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "7"])
	var actions: HandActions = _f.actions(rnd)
	assert_array(actions.questions(3)).contains_exactly([Q.TEN_CARD, Q.RED])
	assert_array(_ask(actions, 3, Q.BUSTS_ME)).is_empty()
	assert_array(_before_hit_questions()).contains_exactly([Q.BUSTS_ME, Q.TEN_CARD, Q.RED])


func _before_hit_questions() -> Array[PartialQuestion.Kind]:
	return _f.actions(_before_hit("7")).questions(4)


# gdlint: ignore=unused-argument
func test_baccarat_high(card: String, high: bool, test_parameters: Array = [
	["5", true],
	["9", true],
	["4", false],
	["A", false],
	["10", false],  # worth 0
	["K", false],
]) -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", card, "A"])
	assert_array(_ask(_f.actions(rnd), 2, Q.HIGH)).contains_exactly([high])


# gdlint: ignore=unused-argument
func test_baccarat_face_card(card: String, face: bool, test_parameters: Array = [
	["J", true],
	["Q", true],
	["K", true],
	["10", false],
	["A", false],
]) -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", card, "A"])
	assert_array(_ask(_f.actions(rnd), 2, Q.FACE_CARD)).contains_exactly([face])


func test_baccarat_offers_high_and_face_card() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A"])
	assert_array(_f.actions(rnd).questions(3)).contains_exactly([Q.HIGH, Q.FACE_CARD])


# gdlint: ignore=unused-argument
func test_high_low_within_three(next: String, within: bool, test_parameters: Array = [
	["4", true],
	["10", true],
	["7", true],  # a tie counts
	["3", false],
	["J", false],
]) -> void:
	var rnd: HighLowRound = _f.high_low(["7", next])
	assert_array(_ask(_f.actions(rnd), 1, Q.WITHIN_THREE)).contains_exactly([within])


# gdlint: ignore=unused-argument
func test_high_low_red(next: String, red: bool, test_parameters: Array = [
	["9H", true],
	["9D", true],
	["9S", false],
	["9C", false],
]) -> void:
	var rnd: HighLowRound = _f.high_low(["7", next])
	assert_array(_ask(_f.actions(rnd), 1, Q.RED)).contains_exactly([red])


func test_high_low_offers_within_three_and_red() -> void:
	var rnd: HighLowRound = _f.high_low(["7", "9"])
	assert_array(_f.actions(rnd).questions(1)).contains_exactly([Q.WITHIN_THREE, Q.RED])


func test_answers_the_card_as_it_reads_now() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "5"])
	rnd.rewrite_card(3, 13, Card.Suit.SPADES)
	assert_array(_ask(_f.actions(rnd), 3, Q.TEN_CARD)).contains_exactly([true])


func test_only_on_the_window_subject() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "5"])
	var actions: HandActions = _f.actions(rnd)
	assert_array(_ask(actions, 1, Q.RED)).is_empty()
	assert_array(actions.used).is_empty()


func test_asks_one_question_unless_the_kit_allows_more() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "KH"])
	var two: Array[PartialQuestion.Kind] = [Q.TEN_CARD, Q.RED]
	assert_array(_f.actions(rnd).partial_reveal(3, two)).is_empty()
	_f.kit.questions_per_reveal = 2
	assert_array(_f.actions(rnd).partial_reveal(3, two)).contains_exactly([true, true])


func test_recorded_with_its_window() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "5"])
	var actions: HandActions = _f.actions(rnd)
	_ask(actions, 3, Q.RED)
	assert_int(actions.used.size()).is_equal(1)
	assert_int(actions.used[0].action).is_equal(ActionKind.Kind.PARTIAL_REVEAL)
	assert_int(actions.used[0].window_number).is_equal(1)
	assert_array(actions.used[0].card_ids).contains_exactly([3])


func test_busts_me_answers_on_a_double() -> void:
	var rnd: BlackjackRound = _f.blackjack(["10", "9", "6", "7", "7"])
	rnd.proceed()
	rnd.proceed()
	rnd.double()
	assert_array(_ask(_f.actions(rnd), 4, Q.BUSTS_ME)).contains_exactly([true])


func test_busts_me_answers_for_the_hand_being_played() -> void:
	# 8 | 8 split: hand 0 takes 2 (10), hand 1 takes K (18). On hand 1, a 5 busts.
	var rnd: BlackjackRound = _f.blackjack(["8", "9", "8", "7", "2", "K", "5"])
	rnd.proceed()
	rnd.proceed()
	rnd.split()
	rnd.stand()
	rnd.hit()
	assert_int(rnd.active_hand_index).is_equal(1)
	assert_array(_ask(_f.actions(rnd), 6, Q.BUSTS_ME)).contains_exactly([true])
