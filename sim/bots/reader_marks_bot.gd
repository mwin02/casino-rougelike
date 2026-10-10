class_name ReaderMarksBot
extends ReaderBot
## The Reader with marks added (spec §10, §12): marks as a supplement to a
## build, the check that they pay as one. It plays as the Reader and, in a
## hand's first window at any blackjack table, makes at most one mark a
## session, on a face-up ten-value card or ace, while the mark costs at most
## MAX_MARK_HEAT. A hole card's symbol, or its lack of one, narrows it to
## the deck's cards alike (§4.3), so it asks about the hole card only when
## the marks leave the answer open. On a house deck (§7.2) the marks say
## nothing and it plays as the Reader.

## A session's first mark while the table is Clean; one at a Watched table
## with a high roll costs more (§7.1).
const MAX_MARK_HEAT: float = 4.0

var _deck: Deck
var _session: TableSession
var _marked: bool = false


func bot_name() -> String:
	return "reader_marks"


func actions_used() -> Array[ActionKind.Kind]:
	var actions: Array[ActionKind.Kind] = super()
	actions.append(ActionKind.Kind.MARK)
	return actions


static func symbol_for(p_kit: ActionKit, card: Card) -> int:
	return MarkerBot.symbol_for(p_kit, card)


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_deck = deck
	_session = session
	_marked = false


func on_window(session: TableSession, hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	var blackjack: BlackjackRound = rnd as BlackjackRound
	if blackjack == null or session.house_deck_swapped():
		super(session, hand)
		return
	if not _marks_answer(blackjack):
		super(session, hand)
	if rnd.window_number != 1 or _marked or not hand.can_use(ActionKind.Kind.MARK):
		return
	if hand.cost_of(ActionKind.Kind.MARK) > MAX_MARK_HEAT:
		return
	for card: Card in rnd.cards_in_play():
		var symbol: int = symbol_for(kit, card)
		if symbol != Card.NO_SYMBOL and not card.is_marked() and rnd.is_face_up(card):
			_marked = hand.mark(card.id, symbol)
			return


## The deck's cards carrying the hole card's symbol (or none), narrowed by
## the answer to the Reader's question when it asked.
func hole_odds(rnd: BlackjackRound) -> Array[float]:
	var odds: Array[float] = _symbol_odds(rnd)
	if odds.is_empty():
		return super(rnd)
	if _hole_ten >= 0:
		return narrow(odds, _hole_ten == 1)
	return odds


## True when the marks already say whether the hole card is a ten.
func _marks_answer(rnd: BlackjackRound) -> bool:
	var odds: Array[float] = _symbol_odds(rnd)
	return not odds.is_empty() and (is_zero_approx(odds[10]) or is_equal_approx(odds[10], 1.0))


## Empty on a house deck, or when the deck holds no card like the hole card.
func _symbol_odds(rnd: BlackjackRound) -> Array[float]:
	if _session.house_deck_swapped():
		return []
	return MarkerBot.symbol_odds(_deck, rnd.dealer_hand.cards[1])
