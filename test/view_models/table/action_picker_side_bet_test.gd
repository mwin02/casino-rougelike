extends GdUnitTestSuite
## The action picker shows side-bet heat (spec §8) before a manipulation: a
## last-step option whose side-bet heat raises the cost shows its full cost.
## Blackjack piles deal player, dealer up, player, hole.

var _fixture: ActionsFixture
var _hand: HandActions
var _picker: ActionPicker


func before_test() -> void:
	_fixture = ActionsFixture.new()
	_fixture.side_bets = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, 1000)]


func _start(rnd: GameRound, reveal_costs: bool = true) -> void:
	_hand = _fixture.actions(rnd)
	_picker = ActionPicker.new(_hand, _fixture.kit, _code, reveal_costs)


func _code(card: Card) -> String:
	return card.short_name()


func _labels() -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in _picker.choices():
		labels.append(choice.label)
	return labels


func _pick(label: String) -> void:
	for choice: Choice in _picker.choices():
		if choice.label == label:
			_picker.pick(choice.id)
			return
	fail("no choice labelled " + label)


func test_an_option_that_costs_side_bet_heat_shows_its_full_cost() -> void:
	# Spec §8: player 7H and 8D with Perfect Pairs on; 8D down pairs them.
	_start(_fixture.blackjack(["7H", "5S", "8D", "9C", "2S"]))
	_pick("Nudge 12")
	_pick("8D")
	var down: String = "Down " + HeatText.number(_hand.nudge_cost(2, -1))
	assert_array(_labels()).contains_exactly(["Up", down])
	_pick(down)
	assert_array(_picker.info_lines).contains_exactly(["8D nudged down"])


func test_side_bet_heat_stays_hidden_without_reveal_costs() -> void:
	_start(_fixture.blackjack(["7H", "5S", "8D", "9C", "2S"]), false)
	_pick("Nudge")
	_pick("8D")
	assert_array(_labels()).contains_exactly(["Up", "Down"])
