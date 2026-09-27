class_name GameRound
extends RefCounted
## What every game's round shares: the pile, the bet limits and bet changes,
## the bet lock (spec §2.2), the count of windows opened this hand, and what
## a window's actions can reach (spec §2.5). Each game fills in its own
## windows, what an adjust moves, and its partial-reveal questions.
##
## Cards in play are the round's own dealt copies. Rewriting one changes this
## hand only; the owned deck is never touched from here.

## The stake placed at the stake window. Bet changes are measured against it.
var opening_bet: int
var limits: BetLimits
var bet_changes: Array[BetChange] = []
## Windows opened this hand, the current one included.
var window_number: int = 0

var _bet_locked: bool = false
## Cards still to deal, front first.
var _pile: Array[Card]


func _init(p_limits: BetLimits, pile: Array[Card]) -> void:
	limits = p_limits
	opening_bet = p_limits.opening
	_pile = pile.duplicate()


## After a manipulation (spec §2.2): no more bet changes this hand.
func lock_bet() -> void:
	_bet_locked = true


func is_bet_locked() -> bool:
	return _bet_locked


## True while a window is open.
func in_window() -> bool:
	return false


## Every dollar on the table now.
func total_bet() -> int:
	return 0


## True once the round has settled.
func is_resolved() -> bool:
	return false


## Dollars won (positive) or lost (negative) this round. 0 until it settles.
func net() -> int:
	return 0


## True in an adjust, while the bet isn't locked.
func can_adjust() -> bool:
	return false


## True in a window that closes into an adjust.
func adjust_follows() -> bool:
	return false


## True when the bet can move now, or in the adjust the open window closes
## into. The screen can offer an adjust in the window this way.
func adjust_ahead() -> bool:
	return can_adjust() or (adjust_follows() and not _bet_locked)


## The smallest total bet an adjust may set now.
func adjust_min() -> int:
	return limits.min_total()


## The largest total bet an adjust may set now.
func adjust_max() -> int:
	return limits.max_total()


## Raises or lowers the bet to new_total, recorded as a bet change. Does
## nothing outside an adjust, past a limit, or without a change.
func adjust(new_total: int) -> void:
	if not can_adjust() or new_total < adjust_min() or new_total > adjust_max():
		return
	var amount: int = new_total - total_bet()
	if amount == 0:
		return
	_apply_adjust(amount)
	bet_changes.append(BetChange.new(BetChange.Kind.ADJUST, amount, _adjust_hand_index()))


## The face-down cards the open window is about. Reveals target only these.
## Empty outside a window.
func window_subjects() -> Array[Card]:
	return []


## Every card an action can target now: the window's subjects plus every
## card dealt this hand, face up or down.
func cards_in_play() -> Array[Card]:
	var result: Array[Card] = _dealt_cards()
	for subject: Card in window_subjects():
		if subject not in result:
			result.append(subject)
	return result


## The next count cards off the pile, as they read, or fewer if it runs out.
func upcoming(count: int) -> Array[Card]:
	return _pile.slice(0, count)


## The partial-reveal questions this game offers on card now.
func questions(_card: Card) -> Array[PartialQuestion.Kind]:
	return []


## The answer to question about card, as the card reads now.
func answer(_question: PartialQuestion.Kind, _card: Card) -> bool:
	push_error("GameRound.answer: not implemented")
	return false


## The card in play with this id, or null.
func card_in_play(id: int) -> Card:
	for card: Card in cards_in_play():
		if card.id == id:
			return card
	return null


## Makes the card in play with this id read as rank/suit for this hand.
func rewrite_card(id: int, rank: int, suit: Card.Suit) -> bool:
	var card: Card = card_in_play(id)
	if card == null or not Card.is_valid_rank(rank):
		return false
	card.rank = rank
	card.suit = suit
	return true


## Puts symbol on the card in play with this id.
func mark_card(id: int, symbol: int) -> bool:
	var card: Card = card_in_play(id)
	if card == null:
		return false
	card.symbol = symbol
	return true


## Every card dealt this hand and still on the table.
func _dealt_cards() -> Array[Card]:
	return []


## Moves amount dollars onto (or off) the bet.
func _apply_adjust(_amount: int) -> void:
	push_error("GameRound._apply_adjust: not implemented")


## The hand an adjust belongs to, or BetChange.NO_HAND.
func _adjust_hand_index() -> int:
	return BetChange.NO_HAND


## Each game calls this when a window opens.
func _count_window() -> void:
	window_number += 1
