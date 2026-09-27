class_name StackedTableDebugVM
extends TableDebugVM
## A debug table whose owned deck is exactly the given cards, dealt in that
## order every hand (StackedTableSession), so card i has id i. heat_floor
## stands in for the deck's floor.

var heat_floor: float = 0.0


static func on(codes: Array[String]) -> StackedTableDebugVM:
	var deck: Deck = Deck.new(0)
	for code: String in codes:
		var card: Card = Card.parse(code)
		deck.add_card(card.rank, card.suit)
	return StackedTableDebugVM.new(TuneConfig.load_default(), deck, GameRng.new(7))


func _new_session(table: Table, p_heat_floor: float) -> TableSession:
	return StackedTableSession.new(
		_config, table, _deck, _layer, _kit, _rng, bankroll, p_heat_floor
	)


func _heat_floor() -> float:
	return heat_floor


## The choice labelled label in choices, or null.
static func find(choices: Array[Choice], label: String) -> Choice:
	for choice: Choice in choices:
		if choice.label == label:
			return choice
	return null


static func labels(choices: Array[Choice]) -> Array[String]:
	var result: Array[String] = []
	for choice: Choice in choices:
		result.append(choice.label)
	return result
