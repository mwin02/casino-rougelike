class_name HighLowRound
extends RefCounted
## One High or Low round (spec §3.3), with its windows as explicit phases.
## Cards come off the front of the pile, and a chain never reshuffles.
##
## Deal one card up. Each call then has a window on the next card and the
## call itself; the first call also has an adjust between them, because the
## bet locks when the chain starts. A correct call reprices the chain value
## and offers bank or continue; a wrong call loses the stake, and a tie keeps
## half the chain value. The chain banks itself at the chain cap or when the
## pile runs out. proceed() closes the current window or adjust. Windows and
## adjusts take no actions yet (block 5).
##
## Calls are priced against the owned deck minus the cards drawn this chain,
## so temporary manipulation isn't priced in. Whether a call wins goes by the
## cards as they read. Any call is allowed, even one no owned card can win.

enum Phase { READY, WINDOW, ADJUST, CALL, DECIDE, RESOLVED }
enum Direction { HIGHER, LOWER }
enum Outcome { NONE, BANKED, LOST, TIE }

var phase: Phase = Phase.READY
## The locked bet. Starts the chain value.
var stake: int
## What banking pays back now: the stake, repriced by each correct call.
var chain_value: int
## Calls made, the current one included once it's settled.
var calls: int = 0
## Every card flipped this chain, as it read. The last one is up.
var cards: Array[Card] = []
var outcome: Outcome = Outcome.NONE

var _rules: HighLowRules
var _pile: Array[Card]
## Owned rank by card id, for every owned card not yet drawn this chain.
var _remaining: Dictionary[int, int] = {}
var _bet_locked: bool = false


## owned is the owned deck (Deck.cards()); pile is the shuffled dealing cards.
func _init(rules: HighLowRules, p_stake: int, owned: Array[Card], pile: Array[Card]) -> void:
	_rules = rules
	stake = p_stake
	chain_value = p_stake
	_pile = pile.duplicate()
	for card: Card in owned:
		_remaining[card.id] = card.rank


func deal() -> void:
	if phase != Phase.READY:
		return
	_draw()
	phase = Phase.WINDOW


## The card up, as it reads.
func current() -> Card:
	return cards.back()


## Closes the current window or adjust. Only the first call has an adjust.
func proceed() -> void:
	match phase:
		Phase.WINDOW:
			phase = Phase.ADJUST if calls == 0 else Phase.CALL
		Phase.ADJUST:
			phase = Phase.CALL


## Bet adjusts happen here, before the first call, while the bet isn't locked.
func can_adjust() -> bool:
	return phase == Phase.ADJUST and not _bet_locked


## After a manipulation (spec §2.2), or once the chain starts.
func lock_bet() -> void:
	_bet_locked = true


func is_bet_locked() -> bool:
	return _bet_locked


## Owned cards not yet drawn this chain.
func remaining() -> int:
	return _remaining.size()


## Remaining owned cards that would win this call against the card up.
func winners(direction: Direction) -> int:
	var up: int = current().rank
	var count: int = 0
	for rank: int in _remaining.values():
		if (rank > up) if direction == Direction.HIGHER else (rank < up):
			count += 1
	return count


## Calls the next card. Named call_next because Object already has call().
func call_next(direction: Direction) -> void:
	if phase != Phase.CALL:
		return
	_bet_locked = true
	var won_by: int = winners(direction)
	var out_of: int = remaining()
	var up: int = current().rank
	calls += 1
	var next: int = _draw().rank
	if next == up:
		chain_value = HighLowRules.tie_value(chain_value)
		_resolve(Outcome.TIE)
	elif (next > up) != (direction == Direction.HIGHER):
		chain_value = 0
		_resolve(Outcome.LOST)
	else:
		var cap: int = _rules.chain_cap(stake)
		chain_value = mini(_rules.call_value(chain_value, won_by, out_of), cap)
		if chain_value >= cap or _pile.is_empty():
			_resolve(Outcome.BANKED)
		else:
			phase = Phase.DECIDE


func bank() -> void:
	if phase == Phase.DECIDE:
		_resolve(Outcome.BANKED)


func continue_chain() -> void:
	if phase == Phase.DECIDE:
		phase = Phase.WINDOW


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	if outcome == Outcome.NONE:
		return 0
	return chain_value - stake


func _resolve(result: Outcome) -> void:
	outcome = result
	phase = Phase.RESOLVED


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	_remaining.erase(card.id)
	cards.append(card)
	return card
