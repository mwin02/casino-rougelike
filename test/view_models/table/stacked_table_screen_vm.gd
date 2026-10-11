class_name StackedTableScreenVM
extends TableScreenVM
## A real table screen whose owned deck is exactly the given cards, dealt in
## that order every hand (StackedTableSession), so card i has id i.
## heat_floor stands in for the deck's floor.

var heat_floor: float = 0.0


static func on(codes: Array[String]) -> StackedTableScreenVM:
	var deck: Deck = Deck.new(0)
	for code: String in codes:
		var card: Card = Card.parse(code)
		deck.add_card(card.rank, card.suit)
	return StackedTableScreenVM.new(TuneConfig.load_default(), deck, GameRng.new(7))


func _new_session(table: Table, p_heat_floor: float) -> TableSession:
	return StackedTableSession.new(
		_config, table, _deck, _layer, _kit, _rng, bankroll, p_heat_floor
	)


func _heat_floor() -> float:
	return heat_floor
