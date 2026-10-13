class_name ManipulationLayer
extends RefCounted
## Temporary card changes from manipulation actions, keyed by card id
## (spec §2.3). Every change lasts the hand. Masking Tape keeps it for the
## rest of the table session; a Cold Seal or Permanent Ink charge writes it into
## the owned deck. Marks stay with the physical card, so a change never moves
## a symbol.
##
## A card holds at most one session change with a hand change on top. When
## the hand ends, a hand change reverts to what the card read before it.
##
## A Switch only moves two identities for the hand and can't be kept. A
## Nudge, Recolour or Palm changes an identity, and keeping it keeps that
## change on the card the identity belongs to, wherever a Switch has put it.


class Change:
	extends RefCounted
	var rank: int
	var suit: Card.Suit
	## The card this identity belongs to: another card's id after a Switch.
	var owner: int = Card.NO_ID
	## True while the identity holds a change a consumable can still keep.
	var keepable: bool = false
	## True while the identity is a taped change, so the card wears the tape.
	var taped: bool = false


var _session: Dictionary[int, Change] = {}
var _hand: Dictionary[int, Change] = {}


## Makes card id read as rank/suit for the rest of this hand.
func change(id: int, rank: int, suit: Card.Suit) -> void:
	if not Card.is_valid_rank(rank):
		push_error("ManipulationLayer.change: bad rank %d" % rank)
		return
	var entry: Change = _new_change(rank, suit)
	entry.owner = _owner(id)
	entry.keepable = true
	_hand[id] = entry


## Each card takes the other's current identity for this hand. a and b are
## the cards as they read now (after any earlier change).
func switch_cards(a: Card, b: Card) -> void:
	var from_a: Change = _moved(a)
	var from_b: Change = _moved(b)
	_hand[a.id] = from_b
	_hand[b.id] = from_a


## Masking Tape: this hand's change to the identity card id shows lasts the
## rest of the table session. False if it has no change this hand.
func tape(id: int) -> bool:
	if not has_hand_change(id):
		return false
	var entry: Change = _hand[id]
	_session[entry.owner] = _new_change(entry.rank, entry.suit)
	_settle(id, true)
	return true


## True while card id reads as a taped change, so the screen draws the tape.
## A newer hand change on top hides it until the hand ends.
func is_taped(id: int) -> bool:
	if _hand.has(id):
		return _hand[id].taped
	return _session.has(id)


## True while card id holds a taped change, whether or not a hand change
## sits on top of it.
func has_tape(id: int) -> bool:
	return _session.has(id)


## True while card id shows a change from this hand that a consumable can
## still keep. A Switch alone is not one.
func has_hand_change(id: int) -> bool:
	return _hand.has(id) and _hand[id].keepable


## Cold Seal or Permanent Ink: this hand's change to the identity card id
## shows is written into deck as an edit of kind source, on the card the
## identity belongs to. False, with nothing changed, if it has no change this
## hand or that card isn't in deck.
func make_permanent(id: int, deck: Deck, source: DeckEdit.Kind) -> bool:
	if source not in DeckEdit.PERMANENT_KINDS:
		var kind_name: String = DeckEdit.Kind.keys()[source]
		push_error("ManipulationLayer.make_permanent: %s is not a permanent source" % kind_name)
		return false
	if not has_hand_change(id):
		return false
	var entry: Change = _hand[id]
	if deck.card(entry.owner) == null:
		return false
	deck.make_permanent(entry.owner, entry.rank, entry.suit, source)
	_session.erase(entry.owner)
	_settle(id, false)
	return true


## A copy of card as it reads under this layer.
func apply_to(card: Card) -> Card:
	var result: Card = card.copy()
	var entry: Change = null
	if _hand.has(card.id):
		entry = _hand[card.id]
	elif _session.has(card.id):
		entry = _session[card.id]
	if entry != null:
		result.rank = entry.rank
		result.suit = entry.suit
	return result


## A copy of card as it reads under the session's taped changes alone,
## without this hand's: what the deck screen shows (spec §4.4).
func session_reading(card: Card) -> Card:
	var result: Card = card.copy()
	if _session.has(card.id):
		result.rank = _session[card.id].rank
		result.suit = _session[card.id].suit
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
	_session.clear()


func to_dict() -> Dictionary:
	return {"session": _changes_to_dict(_session), "hand": _changes_to_dict(_hand)}


static func from_dict(saved: Dictionary) -> ManipulationLayer:
	var layer: ManipulationLayer = ManipulationLayer.new()
	var saved_session: Dictionary = saved["session"]
	var saved_hand: Dictionary = saved["hand"]
	layer._session = _changes_from_dict(saved_session)
	layer._hand = _changes_from_dict(saved_hand)
	return layer


static func _changes_to_dict(changes: Dictionary[int, Change]) -> Dictionary:
	var saved: Dictionary = {}
	for id: int in changes:
		var entry: Change = changes[id]
		saved[id] = {
			"rank": entry.rank, "suit": entry.suit, "owner": entry.owner,
			"keepable": entry.keepable, "taped": entry.taped,
		}
	return saved


static func _changes_from_dict(saved: Dictionary) -> Dictionary[int, Change]:
	var changes: Dictionary[int, Change] = {}
	for id: int in saved:
		var entry: Dictionary = saved[id]
		var rank: int = entry["rank"]
		var suit_value: int = entry["suit"]
		var change: Change = _new_change(rank, suit_value as Card.Suit)
		# Older saves have none of these: a run never saves mid-hand.
		change.owner = entry.get("owner", id)
		change.keepable = entry.get("keepable", false)
		change.taped = entry.get("taped", false)
		changes[id] = change
	return changes


## The card whose identity card id shows now.
func _owner(id: int) -> int:
	return _hand[id].owner if _hand.has(id) else id


## The identity card shows now, as the hand change another card takes in a
## Switch.
func _moved(card: Card) -> Change:
	var entry: Change = _new_change(card.rank, card.suit)
	entry.owner = _owner(card.id)
	entry.keepable = has_hand_change(card.id)
	entry.taped = is_taped(card.id)
	return entry


## The change card id shows has been kept. On its own card nothing of the
## hand is left; switched away, it stays where it is until the hand ends.
func _settle(id: int, taped: bool) -> void:
	if _hand[id].owner == id:
		_hand.erase(id)
		return
	_hand[id].keepable = false
	_hand[id].taped = taped


static func _new_change(rank: int, suit: Card.Suit) -> Change:
	var entry: Change = Change.new()
	entry.rank = rank
	entry.suit = suit
	return entry
