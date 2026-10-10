class_name ReaderMarksBot
extends ReaderBot
## The Reader with marks added (spec §10, §12): marks as a supplement to a
## build, the check that they pay as one. It plays as the Reader and, in a
## hand's first window at any blackjack table, marks one face-up ten-value
## card or ace while a mark costs at most MAX_MARK_HEAT. A hole card's
## symbol, or its lack of one, narrows it to the deck's cards alike (§4.3),
## so a marked hole card needs no question.

## A session's first mark while the table is Clean; the second costs double
## (§4.3) and so does one at a Watched table with a high roll.
const MAX_MARK_HEAT: float = 4.0
## The marks it holds at most: each one raises the heat floor (§4.2).
const MARK_TARGET: int = 20

var _deck: Deck


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


func on_window(session: TableSession, hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	var blackjack: BlackjackRound = rnd as BlackjackRound
	if blackjack == null or not blackjack.dealer_hand.cards[1].is_marked():
		super(session, hand)
	if blackjack == null or rnd.window_number != 1:
		return
	for card: Card in rnd.cards_in_play():
		if not hand.can_use(ActionKind.Kind.MARK):
			return
		if hand.cost_of(ActionKind.Kind.MARK) > MAX_MARK_HEAT:
			return
		if _deck.marked_count() >= MARK_TARGET:
			return
		var symbol: int = symbol_for(kit, card)
		if symbol != Card.NO_SYMBOL and not card.is_marked() and rnd.is_face_up(card):
			hand.mark(card.id, symbol)


## The deck's cards carrying the hole card's symbol (or none), narrowed by
## the answer to the Reader's question when it asked.
func hole_odds(rnd: BlackjackRound) -> Array[float]:
	var odds: Array[float] = MarkerBot.symbol_odds(_deck, rnd.dealer_hand.cards[1])
	if odds.is_empty():
		return super(rnd)
	if _hole_ten >= 0:
		return narrow(odds, _hole_ten == 1)
	return odds
