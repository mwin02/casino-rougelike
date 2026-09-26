class_name HighLowRoundFixture
extends RefCounted
## Builds High or Low rounds for the round suites. The owned deck holds
## exactly the given cards, and the pile deals them in that order, so card i
## has id i. Changes put on layer before new_round() show in the pile only, as a
## manipulation would.

const BET: int = 1000

var rules: HighLowRules = HighLowRules.from_config(TuneConfig.load_default())
var deck: Deck
var layer: ManipulationLayer = ManipulationLayer.new()


func build_deck(codes: Array[String]) -> void:
	deck = Deck.new(0)
	for code: String in codes:
		var card: Card = Card.parse(code)
		deck.add_card(card.rank, card.suit)


func new_round(stake: int = BET) -> HighLowRound:
	return HighLowRound.new(rules, stake, deck.cards(), deck.dealing_cards(layer))


## A fresh deck of codes, dealt: the first card is up, in the first window.
func dealt(codes: Array[String], stake: int = BET) -> HighLowRound:
	build_deck(codes)
	var rnd: HighLowRound = new_round(stake)
	rnd.deal()
	return rnd


## Passes any window and adjust up to the call.
static func to_call(rnd: HighLowRound) -> void:
	while rnd.phase == HighLowRound.Phase.WINDOW or rnd.phase == HighLowRound.Phase.ADJUST:
		rnd.proceed()


## Continues the chain if a call just won, then makes the next call.
static func take(rnd: HighLowRound, direction: HighLowRound.Direction) -> void:
	if rnd.phase == HighLowRound.Phase.DECIDE:
		rnd.continue_chain()
	to_call(rnd)
	rnd.call_next(direction)
