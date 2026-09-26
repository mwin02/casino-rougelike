class_name ManipulationLayer
extends RefCounted
## Temporary card changes from manipulation actions, keyed by card id. They
## last the hand or the table session (spec §2.3) and never touch the owned
## deck. Marks stay with the physical card, so a change never moves a symbol.
##
## A card holds at most one session change with a hand change on top. A hand
## change reverts to what the card read before it; a session change replaces
## everything on the card, lifetime included.

enum Duration { HAND, SESSION }


class Change:
	extends RefCounted
	var rank: int
	var suit: Card.Suit
	## Table sessions left, counting the current one. Session changes only.
	var sessions_left: int


var _session: Dictionary[int, Change] = {}
var _hand: Dictionary[int, Change] = {}


## Makes card id read as rank/suit. carry_sessions extends a SESSION change
## into that many later table sessions (Long Con, spec §9).
func change(
	id: int, rank: int, suit: Card.Suit, duration: Duration, carry_sessions: int = 0
) -> void:
	if not Card.is_valid_rank(rank):
		push_error("ManipulationLayer.change: bad rank %d" % rank)
		return
	var entry: Change = Change.new()
	entry.rank = rank
	entry.suit = suit
	entry.sessions_left = 1 + carry_sessions
	if duration == Duration.HAND:
		_hand[id] = entry
	else:
		_hand.erase(id)
		_session[id] = entry


## Each card takes the other's current identity. a and b are the cards as
## they read now (after any earlier change).
func switch_cards(a: Card, b: Card, duration: Duration, carry_sessions: int = 0) -> void:
	var a_rank: int = a.rank
	var a_suit: Card.Suit = a.suit
	change(a.id, b.rank, b.suit, duration, carry_sessions)
	change(b.id, a_rank, a_suit, duration, carry_sessions)


## A copy of card as it reads under this layer.
func apply_to(card: Card) -> Card:
	var result: Card = card.copy()
	var entry: Change = _hand.get(card.id, _session.get(card.id))
	if entry != null:
		result.rank = entry.rank
		result.suit = entry.suit
	return result


## How many cards read differently under this layer.
func size() -> int:
	var ids: Dictionary[int, bool] = {}
	for id: int in _session:
		ids[id] = true
	for id: int in _hand:
		ids[id] = true
	return ids.size()


func end_hand() -> void:
	_hand.clear()


func end_session() -> void:
	_hand.clear()
	for id: int in _session.keys():
		_session[id].sessions_left -= 1
		if _session[id].sessions_left <= 0:
			_session.erase(id)
