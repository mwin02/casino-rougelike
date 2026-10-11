class_name RevealBot
extends HonestAdjusterBot
## The reveal bots (spec §12). In each hand's first window the bot full-reveals
## the key face-down card: the dealer's hole card, the player's second card
## in baccarat. At High or Low, which takes no full reveal (§3.3), it looks
## ahead at the next card. Blackjack plays into the hole
## card and High or Low calls the side the card wins. Reveal-only stops
## there; reveal + adjust also sizes the bet on it, as the honest adjuster
## sizes on the cards showing.

## Cards the bot has seen face down this hand, by id.
var _revealed: Dictionary[int, Card] = {}
var _name: String
var _adjusts: bool


func _init(p_name: String, p_adjusts: bool) -> void:
	_name = p_name
	_adjusts = p_adjusts


func bot_name() -> String:
	return _name


func actions_used() -> Array[ActionKind.Kind]:
	return [ActionKind.Kind.FULL_REVEAL, ActionKind.Kind.LOOK_AHEAD]


func play_hand(session: TableSession, hand: HandActions) -> void:
	_revealed.clear()
	super(session, hand)


func on_window(session: TableSession, hand: HandActions) -> void:
	if session.current_round().window_number == 1:
		reveal_subject(session.current_round(), hand)


## Full-reveals the window's first subject not already seen; at High or
## Low, looks ahead at the next card while that is allowed.
func reveal_subject(rnd: GameRound, hand: HandActions) -> void:
	if rnd is HighLowRound:
		for card: Card in hand.look_ahead():
			_revealed[card.id] = card
		return
	if not hand.can_use(ActionKind.Kind.FULL_REVEAL):
		return
	for subject: Card in rnd.window_subjects():
		if not _revealed.has(subject.id):
			var card: Card = hand.full_reveal(subject.id)
			if card != null:
				_revealed[card.id] = card
			return


func on_adjust(session: TableSession, hand: HandActions) -> void:
	if _adjusts:
		super(session, hand)


func hole_odds(rnd: BlackjackRound) -> Array[float]:
	var hole: Card = rnd.dealer_hand.cards[1]
	if _revealed.has(hole.id):
		return BlackjackEv.known(_revealed[hole.id])
	return super(rnd)


func knows(card: Card, index: int, shown: int) -> bool:
	return _revealed.has(card.id) or super(card, index, shown)


## The side the revealed next card wins; the best price on a tie.
func call_high_low(
	session: TableSession, hand: HandActions, rnd: HighLowRound
) -> HighLowRound.Direction:
	var next: Card = _next_card(rnd)
	if next == null or next.rank == rnd.current().rank:
		return super(session, hand, rnd)
	if is_higher(next, rnd):
		return HighLowRound.Direction.HIGHER
	return HighLowRound.Direction.LOWER


## With the next card known, a win at its price or a tie's half.
func high_low_value(rnd: HighLowRound) -> float:
	var next: Card = _next_card(rnd)
	if next == null:
		return super(rnd)
	if next.rank == rnd.current().rank:
		return HighLowRules.tie_value(rnd.chain_value) - rnd.chain_value
	var direction: HighLowRound.Direction = (
		HighLowRound.Direction.HIGHER
		if is_higher(next, rnd)
		else HighLowRound.Direction.LOWER
	)
	return rnd.value_if_won(direction) - rnd.chain_value


## The revealed card for this call, while it's still to come.
func _next_card(rnd: HighLowRound) -> Card:
	if rnd.calls > 0 or _revealed.is_empty():
		return null
	var next: Card = _revealed.values()[0]
	return next
