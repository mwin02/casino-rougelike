class_name MarkerBot
extends HonestAdjusterBot
## The Marker (spec §10, §12), at blackjack only: setup at low stakes,
## payoff at high. At a low-stakes table it marks the ten-value cards and
## aces it sees face up, one symbol for each, while a mark costs at most
## MAX_MARK_HEAT and the deck holds fewer than MARK_TARGET marks. Its
## Luminous Ink symbol, once owned, goes on the tens. Marks show on
## face-down cards (§4.3), so at any table the hole card's symbol narrows it
## to the deck's cards that carry it, and the bot plays and sizes the bet
## on that, as the honest adjuster does on the cards showing.

## Every ten-value card and ace of a standard deck.
const MARK_TARGET: int = 20
const MAX_MARK_HEAT: float = 9.0


## Its route: low stakes until the deck holds its marks, then high.
class Plan:
	extends RunPlan

	func stakes_order(deck: Deck) -> Array[TableStakes.Kind]:
		if deck.marked_count() >= MARK_TARGET:
			return [TableStakes.Kind.HIGH, TableStakes.Kind.LOW]
		return [TableStakes.Kind.LOW, TableStakes.Kind.HIGH]


var _deck: Deck


func bot_name() -> String:
	return "marker"


func plays(game: GameKind.Kind) -> bool:
	return game == GameKind.Kind.BLACKJACK


func actions_used() -> Array[ActionKind.Kind]:
	return [ActionKind.Kind.MARK]


## Buys cheaper marks, a lower heat floor, and pay on marked cards (§9).
func run_plan() -> RunPlan:
	var plan: Plan = Plan.new()
	plan.games = [GameKind.Kind.BLACKJACK]
	plan.wishlist = [
		ItemKind.Kind.TELL_READER, ItemKind.Kind.FORGED_PAPERS, ItemKind.Kind.SIGNATURE,
		ItemKind.Kind.LUMINOUS_INK,
	]
	return plan


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_deck = deck


func on_window(session: TableSession, hand: HandActions) -> void:
	if session.table.stakes != TableStakes.Kind.LOW:
		return
	var rnd: GameRound = session.current_round()
	for card: Card in rnd.cards_in_play():
		if _deck.marked_count() >= MARK_TARGET or hand.cost_of(ActionKind.Kind.MARK) > MAX_MARK_HEAT:
			return
		var symbol: int = _symbol_for(card)
		if symbol != Card.NO_SYMBOL and not card.is_marked() and rnd.is_face_up(card):
			hand.mark(card.id, symbol)


## The hole card's odds from the deck's cards carrying its symbol (or none).
func hole_odds(rnd: BlackjackRound) -> Array[float]:
	var hole: Card = rnd.dealer_hand.cards[1]
	var alike: Array[Card] = []
	for card: Card in _deck.cards():
		if card.symbol == hole.symbol:
			alike.append(card)
	if alike.is_empty():
		return super(rnd)
	var odds: Array[float] = []
	odds.resize(BlackjackEv.VALUES + 1)
	odds.fill(0.0)
	for card: Card in alike:
		odds[BlackjackEv.value_of(card)] += 1.0 / alike.size()
	return odds


## Tens take the first symbol (Luminous Ink's when owned), aces the next.
func _symbol_for(card: Card) -> int:
	var symbols: Array[int] = kit.luminous_symbols.duplicate()
	for symbol: int in kit.symbols:
		if symbol not in symbols:
			symbols.append(symbol)
	if symbols.size() < 2:
		return Card.NO_SYMBOL
	if BlackjackEv.value_of(card) == 10:
		return symbols[0]
	if card.is_ace():
		return symbols[1]
	return Card.NO_SYMBOL
