extends GdUnitTestSuite
## The Tricks screen's history (block U2b): one row for each thing done this
## hand, newest first, and the ways to keep a change on the row of the card
## that now shows it (spec §2.3). Blackjack piles deal player 0 and 2,
## dealer up 1, hole 3, next 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _fixture: ActionsFixture
var _hand: HandActions
var _picker: ActionPicker


func before_test() -> void:
	_fixture = ActionsFixture.new()
	_fixture.kit.masking_tape = 1
	_fixture.kit.cold_seals = 1
	_hand = _fixture.actions(_fixture.blackjack(BLACKJACK))
	_picker = ActionPicker.new(_hand, _fixture.kit, _code)
	_picker.for_screen = true


func _code(card: Card) -> String:
	return card.short_name()


func _nudge_up(card_id: int) -> void:
	_picker.pick(ActionKind.Kind.NUDGE)
	_picker.pick(card_id)
	_picker.pick(ActionPicker.UP)


func _switch(a_id: int, b_id: int) -> void:
	_picker.pick(ActionKind.Kind.SWITCH)
	_picker.pick(a_id)
	_picker.pick(b_id)


func test_no_history_before_anything_is_done() -> void:
	assert_array(_picker.history()).is_empty()


func test_each_action_is_a_row_newest_first() -> void:
	_nudge_up(2)
	_picker.pick(ActionKind.Kind.FULL_REVEAL)
	_picker.pick(3)
	var rows: Array[TrickRow] = _picker.history()
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0].text).is_equal("5C revealed")
	assert_str(rows[1].text).is_equal("7D nudged up")


func test_a_change_carries_its_keeps_and_a_read_carries_none() -> void:
	_nudge_up(2)
	_picker.pick(ActionKind.Kind.FULL_REVEAL)
	_picker.pick(3)
	var rows: Array[TrickRow] = _picker.history()
	assert_array(rows[0].keeps).is_empty()
	assert_int(rows[1].keeps.size()).is_equal(ActionPicker.Keep.size())
	assert_str(rows[1].keep_card).is_equal("8D")
	assert_str(rows[1].keeps[ActionPicker.Keep.TAPE].label).is_equal("Tape")
	assert_str(rows[1].keeps[ActionPicker.Keep.TAPE].detail).is_equal("×1")


func test_a_keep_with_none_left_is_disabled() -> void:
	_nudge_up(2)
	var keeps: Array[Choice] = _picker.history()[0].keeps
	assert_bool(keeps[ActionPicker.Keep.TAPE].enabled).is_true()
	assert_bool(keeps[ActionPicker.Keep.INK].enabled).is_false()


func test_a_switch_carries_no_keeps() -> void:
	_switch(0, 2)
	assert_array(_picker.history()[0].keeps).is_empty()


func test_a_switched_change_is_kept_from_the_switchs_row() -> void:
	_nudge_up(2)
	_switch(2, 0)
	var rows: Array[TrickRow] = _picker.history()
	assert_array(rows[1].keeps).is_empty()
	assert_int(rows[0].keeps.size()).is_equal(ActionPicker.Keep.size())
	assert_str(rows[0].keep_card).is_equal("8D")


func test_keeping_adds_a_row_and_takes_the_keeps_away() -> void:
	_nudge_up(2)
	_picker.keep(_picker.history()[0].keeps[ActionPicker.Keep.TAPE].id)
	var rows: Array[TrickRow] = _picker.history()
	assert_str(rows[0].text).is_equal("8D taped")
	for row: TrickRow in rows:
		assert_array(row.keeps).is_empty()


func test_keeps_stay_on_the_change_when_the_card_is_read_after() -> void:
	_nudge_up(3)
	_picker.pick(ActionKind.Kind.FULL_REVEAL)
	_picker.pick(3)
	var rows: Array[TrickRow] = _picker.history()
	assert_array(rows[0].keeps).is_empty()
	assert_int(rows[1].keeps.size()).is_equal(ActionPicker.Keep.size())


func test_a_refused_keep_leaves_the_keeps_on_the_change() -> void:
	_nudge_up(2)
	var seal: int = _picker.history()[0].keeps[ActionPicker.Keep.SEAL].id
	_fixture.kit.cold_seals = 0
	_picker.keep(seal)
	var rows: Array[TrickRow] = _picker.history()
	assert_str(rows[0].text).is_equal("Seal refused")
	assert_array(rows[0].keeps).is_empty()
	assert_int(rows[1].keeps.size()).is_equal(ActionPicker.Keep.size())
