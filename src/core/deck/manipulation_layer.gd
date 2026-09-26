class_name ManipulationLayer
extends RefCounted
## Temporary card changes from manipulation actions, keyed by card id
## (spec §2.3). Every change lasts the hand. A Hold-Out keeps it for the rest
## of the table session; a Cold Seal or Permanent Ink charge writes it into
## the owned deck. Marks stay with the physical card, so a change never moves
## a symbol.
##
## A card holds at most one session change with a hand change on top. When
## the hand ends, a hand change reverts to what the card read before it.


class Change:
	extends RefCounted
	var rank: int
	var suit: Card.Suit
	## The other card of a Switch, or Card.NO_ID. A consumable covers both.
	var partner: int = Card.NO_ID


var _session: Dictionary[int, Change] = {}
var _hand: Dictionary[int, Change] = {}


## Makes card id read as rank/suit for the rest of this hand.
func change(id: int, rank: int, suit: Card.Suit) -> void:
	if not Card.is_valid_rank(rank):
		push_error("ManipulationLayer.change: bad rank %d" % rank)
		return
	_hand[id] = _new_change(rank, suit, Card.NO_ID)


## Each card takes the other's current identity for this hand. a and b are
## the cards as they read now (after any earlier change).
func switch_cards(a: Card, b: Card) -> void:
	_hand[a.id] = _new_change(b.rank, b.suit, b.id)
	_hand[b.id] = _new_change(a.rank, a.suit, a.id)


## Hold-Out: this hand's change to card id lasts the rest of the table
## session. False if the card has no change this hand.
func hold_out(id: int) -> bool:
	if not _hand.has(id):
		return false
	for held: int in _covered(id):
		_session[held] = _hand[held]
		_hand.erase(held)
	return true


## Cold Seal or Permanent Ink: this hand's change to card id is written into
## deck as an edit of kind source. False, with nothing changed, if the card
## has no change this hand or a covered card isn't in deck.
func make_permanent(id: int, deck: Deck, source: DeckEdit.Kind) -> bool:
	if source not in DeckEdit.PERMANENT_KINDS:
		var kind_name: String = DeckEdit.Kind.keys()[source]
		push_error("ManipulationLayer.make_permanent: %s is not a permanent source" % kind_name)
		return false
	if not _hand.has(id):
		return false
	var covered: Array[int] = _covered(id)
	for sealed: int in covered:
		if deck.card(sealed) == null:
			return false
	for sealed: int in covered:
		var entry: Change = _hand[sealed]
		deck.make_permanent(sealed, entry.rank, entry.suit, source)
		_hand.erase(sealed)
		_session.erase(sealed)
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


## Card id plus its Switch partner, if the partner's change is still this hand's.
func _covered(id: int) -> Array[int]:
	var ids: Array[int] = [id]
	var partner: int = _hand[id].partner
	if partner != Card.NO_ID and _hand.has(partner) and _hand[partner].partner == id:
		ids.append(partner)
	return ids


func _new_change(rank: int, suit: Card.Suit, partner: int) -> Change:
	var entry: Change = Change.new()
	entry.rank = rank
	entry.suit = suit
	entry.partner = partner
	return entry
