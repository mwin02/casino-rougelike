class_name DeckViewVM
extends RefCounted
## The deck screen (spec §4.4): every card in the owned deck, face up, as it
## deals now. A taped card reads as its tape says and wears it (§2.3); any
## other card wears the look of its last permanent change (§4.1). This
## hand's changes don't show, and removed cards are only missing from the
## count. The legend counts each of the player's symbols (§4.3) and can dim
## every card without one of them.
##
## It reads the deck each time it's asked, so it stays right while open. The
## kit and the house deck are as they were when it was opened.

const HOUSE_DECK_NOTE: String = "The pit is dealing a house deck."
const LOOKS: Dictionary[DeckEdit.Kind, CardView.Change] = {
	DeckEdit.Kind.ADD: CardView.Change.ADDED,
	DeckEdit.Kind.REFORGE_RUMMAGE: CardView.Change.REFORGED,
	DeckEdit.Kind.REFORGE_TOUCH_UP: CardView.Change.REFORGED,
	DeckEdit.Kind.REFORGE_FULL: CardView.Change.REFORGED,
	DeckEdit.Kind.COLD_SEAL: CardView.Change.SEALED,
	DeckEdit.Kind.PERMANENT_INK: CardView.Change.INKED,
}

var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
## The table is dealing the casino's deck, not this one (spec §7.2).
var _house_deck: bool
## The symbol the legend filters on, or Card.NO_SYMBOL.
var _filter: int = Card.NO_SYMBOL


func _init(
	deck: Deck, layer: ManipulationLayer, kit: ActionKit, house_deck: bool = false
) -> void:
	_deck = deck
	_layer = layer
	_kit = kit
	_house_deck = house_deck


## Every card, by suit and then rank, ace first.
func cards() -> Array[CardView]:
	var changes: Dictionary[int, CardView.Change] = {}
	for edit: DeckEdit in _deck.edits():
		if LOOKS.has(edit.kind):
			changes[edit.card_id] = LOOKS[edit.kind]
	var views: Array[CardView] = []
	for owned: Card in _deck.cards():
		var taped: bool = _layer.has_tape(owned.id)
		var view: CardView = CardView.new(_layer.session_reading(owned), false, taped)
		if not taped and changes.has(owned.id):
			view.change = changes[owned.id]
		view.dimmed = _filter != Card.NO_SYMBOL and view.symbol != _filter
		views.append(view)
	views.sort_custom(_before)
	return views


## One suit's cards as they read now, ace to king.
func row(suit: Card.Suit) -> Array[CardView]:
	var views: Array[CardView] = []
	for view: CardView in cards():
		if view.suit == suit:
			views.append(view)
	return views


## "52 cards".
func count_text() -> String:
	var count: int = _deck.size()
	return "%d %s" % [count, "card" if count == 1 else "cards"]


## Says the table isn't dealing this deck; empty when it is.
func house_deck_note() -> String:
	return HOUSE_DECK_NOTE if _house_deck else ""


## One row for each symbol the player owns, marked cards or not, and for
## any other symbol still on a card: a symbol item lost to a sweep leaves
## its marks behind (spec §7.6).
func legend() -> Array[LegendRow]:
	var counts: Dictionary[int, int] = {}
	for symbol: int in _kit.symbols:
		counts[symbol] = 0
	for owned: Card in _deck.cards():
		if owned.is_marked():
			var so_far: int = counts[owned.symbol] if counts.has(owned.symbol) else 0
			counts[owned.symbol] = so_far + 1
	var symbols: Array[int] = counts.keys()
	symbols.sort()
	var rows: Array[LegendRow] = []
	for symbol: int in symbols:
		rows.append(LegendRow.new(symbol, counts[symbol], symbol == _filter))
	return rows


## Dims every card without this symbol; the same symbol again clears it.
func toggle_filter(symbol: int) -> void:
	_filter = Card.NO_SYMBOL if symbol == _filter else symbol


func _before(a: CardView, b: CardView) -> bool:
	if a.suit != b.suit:
		return a.suit < b.suit
	if a.rank != b.rank:
		return a.rank < b.rank
	return a.id < b.id
