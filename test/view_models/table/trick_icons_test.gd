extends GdUnitTestSuite
## The Tricks screen's symbols (block U2b): each action, keep, suit, mark
## and nudge direction names the icon the screen draws for it, and every
## icon named has its art. Blackjack piles deal player 0 and 2, dealer up
## 1, hole 3, next 4.

const BLACKJACK: Array[String] = ["KS", "9H", "7D", "5C", "2S", "3H"]

var _fixture: ActionsFixture
var _picker: ActionPicker


func before_test() -> void:
	_fixture = ActionsFixture.new()
	_fixture.kit.masking_tape = 1
	_picker = ActionPicker.new(
		_fixture.actions(_fixture.blackjack(BLACKJACK)), _fixture.kit, _code
	)
	_picker.for_screen = true


func _code(card: Card) -> String:
	return card.short_name()


func _icons(choices: Array[Choice]) -> Array[String]:
	var icons: Array[String] = []
	for choice: Choice in choices:
		icons.append(choice.icon)
		assert_bool(FileAccess.file_exists(Choice.icon_path(choice.icon))).is_true()
	return icons


func test_each_action_names_its_icon() -> void:
	assert_array(_icons(_picker.choices())).contains_exactly([
		"icons/partial_reveal", "icons/mark", "icons/full_reveal", "icons/look_ahead",
		"icons/recolour", "icons/nudge", "icons/switch", "icons/palm",
	])


func test_nudge_directions_name_their_icons() -> void:
	_picker.pick(ActionKind.Kind.NUDGE)
	_picker.pick(2)
	assert_array(_icons(_picker.choices())).contains_exactly(["icons/up", "icons/down"])


func test_suits_name_the_cards_own_art() -> void:
	_picker.pick(ActionKind.Kind.RECOLOUR)
	_picker.pick(2)
	assert_array(_icons(_picker.choices())).contains_exactly([
		"cards/suit_clubs", "cards/suit_diamonds", "cards/suit_hearts", "cards/suit_spades",
	])


func test_marks_name_the_cards_own_art() -> void:
	_fixture.kit.symbols = [0, 4]
	_picker.pick(ActionKind.Kind.MARK)
	_picker.pick(2)
	assert_array(_icons(_picker.choices())).contains_exactly(
		["cards/mark_1_star", "cards/mark_5_ring"]
	)


func test_keeps_name_their_icons() -> void:
	_picker.pick(ActionKind.Kind.NUDGE)
	_picker.pick(2)
	_picker.pick(ActionPicker.UP)
	assert_array(_icons(_picker.history()[0].keeps)).contains_exactly(
		["icons/tape", "icons/seal", "icons/ink"]
	)


func test_the_debug_table_names_no_icons() -> void:
	_picker.for_screen = false
	for choice: Choice in _picker.choices():
		assert_str(choice.icon).is_empty()
