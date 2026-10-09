class_name ManipulateMaxBot
extends Bot
## Manipulate-max (spec §12): opens at the table maximum, never adjusts, and
## rescues losing hands (§2.2). It full-reveals the cards that decide the
## hand (blackjack's hole card in the final window, both baccarat second
## cards, High or Low's next card), values the hand, and if it is losing
## makes the one change that helps most: a Nudge when one brings the hand
## to even or better, otherwise a Palm while the session still has it.


## One candidate change and the hand's value after it.
class Change:
	var action: ActionKind.Kind
	var card: Card
	var rank: int
	var value: float


var _baccarat_rules: BaccaratRules
var _baccarat_odds: Array[float] = []
## High or Low's next card as revealed (and changed), this call.
var _next: Card


func bot_name() -> String:
	return "manipulate_max"


## Reckless: sits until backed off (§7.4, §12).
func stands_up() -> bool:
	return false


## Chases the quota and cashes out on reaching it.
func cash_out_pct() -> int:
	return 100


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_baccarat_rules = BaccaratRules.from_config(config)
	_baccarat_odds = BaccaratOdds.value_odds(deck.cards())


func play_hand(session: TableSession, hand: HandActions) -> void:
	_next = null
	super(session, hand)


func opening_bet(session: TableSession) -> int:
	return mini(session.table.table_max, session.bankroll)


func on_window(session: TableSession, hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	var subjects: Array[Card] = rnd.window_subjects()
	if subjects.is_empty() or not hand.can_use(ActionKind.Kind.FULL_REVEAL):
		return
	if rnd is BlackjackRound:
		var blackjack: BlackjackRound = rnd
		if blackjack.window == BlackjackRound.WindowKind.FINAL:
			var hole: Card = hand.full_reveal(subjects[0].id)
			_rescue(hand, [hole], _blackjack_value.bind(blackjack, hole))
	elif rnd is BaccaratRound and rnd.window_number == 1:
		var baccarat: BaccaratRound = rnd
		var seen: Array[Card] = [hand.full_reveal(subjects[0].id), hand.full_reveal(subjects[1].id)]
		_rescue(hand, seen, _baccarat_value.bind(baccarat, seen))
	elif rnd is HighLowRound:
		var high_low: HighLowRound = rnd
		_next = hand.full_reveal(subjects[0].id)
		_rescue(hand, [_next], _high_low_value.bind(high_low))


## The side the next card wins, as it now reads.
func call_high_low(
	session: TableSession, hand: HandActions, rnd: HighLowRound
) -> HighLowRound.Direction:
	if _next == null or _next.rank == rnd.current().rank:
		return super(session, hand, rnd)
	if _next.rank > rnd.current().rank:
		return HighLowRound.Direction.HIGHER
	return HighLowRound.Direction.LOWER


## value(cards) values the hand with the seen cards as they read. When it is
## below 0, tries a Nudge each way and a Palm to each rank on every seen
## card, and makes the best change.
func _rescue(hand: HandActions, seen: Array[Card], value: Callable) -> void:
	var now: float = value.call()
	if now >= 0.0:
		return
	var best_nudge: Change = null
	var best_palm: Change = null
	for card: Card in seen:
		for step: int in [-1, 1]:
			if Card.is_valid_rank(card.rank + step) and hand.can_use(ActionKind.Kind.NUDGE):
				best_nudge = _better(best_nudge, _try(ActionKind.Kind.NUDGE, card, card.rank + step, value))
		if hand.can_use(ActionKind.Kind.PALM):
			for rank: int in range(1, 14):
				best_palm = _better(best_palm, _try(ActionKind.Kind.PALM, card, rank, value))
	var pick: Change = best_nudge
	if pick == null or (pick.value < 0.0 and best_palm != null and best_palm.value > pick.value):
		pick = best_palm
	if pick == null or pick.value <= now:
		return
	if pick.action == ActionKind.Kind.NUDGE:
		hand.nudge(pick.card.id, pick.rank - pick.card.rank)
	else:
		hand.palm(pick.card.id, pick.rank, pick.card.suit)
	pick.card.rank = pick.rank


## The hand's value with card read as rank, card left as it was.
func _try(action: ActionKind.Kind, card: Card, rank: int, value: Callable) -> Change:
	var change: Change = Change.new()
	change.action = action
	change.card = card
	change.rank = rank
	var was: int = card.rank
	card.rank = rank
	change.value = value.call()
	card.rank = was
	return change


static func _better(best: Change, candidate: Change) -> Change:
	return candidate if best == null or candidate.value > best.value else best


## Every standing hand's stake × its value against the hole as revealed.
func _blackjack_value(rnd: BlackjackRound, revealed: Card) -> float:
	var hole: Array[float] = BlackjackEv.known(revealed)
	var value: float = 0.0
	for player: BlackjackHand in rnd.hands:
		var standing: float = strategy.stand_value(player.total(), rnd.dealer_hand.cards[0], hole)
		value += player.stake * standing
	return value


## The bet side's value with every card showing but the third cards.
func _baccarat_value(rnd: BaccaratRound, seen: Array[Card]) -> float:
	var player: Array[int] = [BaccaratHand.value(rnd.player_hand.cards[0])]
	var banker: Array[int] = [BaccaratHand.value(rnd.banker_hand.cards[0])]
	player.append(BaccaratHand.value(seen[0]))
	banker.append(BaccaratHand.value(seen[1]))
	var outcomes: Array[float] = BaccaratOdds.outcomes(player, banker, _baccarat_odds)
	return BaccaratOdds.side_value(outcomes, rnd.side, _baccarat_rules)


## A tie loses half; any other next card wins its call.
func _high_low_value(rnd: HighLowRound) -> float:
	return -0.5 if _next.rank == rnd.current().rank else 1.0
