class_name SideBetView
extends RefCounted
## What the player knows of this hand's cards, for side-bet values (§8).
## Face-up cards are always known; this holds the rest: cards seen (revealed,
## looked ahead at, palmed), the faces the player still believes cards wear
## after changing them unseen, and faces palmed away unseen.
##
## Beliefs keep a value from ever depending on a face the player hasn't
## seen: a blind Nudge leaves the card's believed face as it was, and a face
## palmed away blind still counts among the unseen cards.

var _seen: Dictionary[int, bool] = {}
var _believed: Dictionary[int, Card] = {}
var _vanished: Array[Card] = []


func sees(card_id: int) -> bool:
	return _seen.has(card_id)


func see(card_id: int) -> void:
	_seen[card_id] = true


func set_seen(card_id: int, value: bool) -> void:
	if value:
		_seen[card_id] = true
	else:
		_seen.erase(card_id)


## The face the player believes an unseen card wears.
func face_of(card: Card) -> Card:
	return _believed.get(card.id, card)


## card is about to change unseen: the player goes on believing its face.
func believe(card: Card) -> void:
	if not _believed.has(card.id):
		_believed[card.id] = card.copy()


## card is about to be palmed unseen: its face leaves the table blind.
func vanish(card: Card) -> void:
	_vanished.append(face_of(card).copy())
	_believed.erase(card.id)


## Two cards trade faces: what the player knows goes with each face.
func swap(a: Card, a_seen: bool, b: Card, b_seen: bool) -> void:
	set_seen(a.id, b_seen)
	set_seen(b.id, a_seen)
	var a_belief: Card = _believed.get(a.id)
	var b_belief: Card = _believed.get(b.id)
	_believed.erase(a.id)
	_believed.erase(b.id)
	if b_belief != null:
		_believed[a.id] = b_belief
	if a_belief != null:
		_believed[b.id] = a_belief


## Faces palmed away unseen.
func vanished() -> Array[Card]:
	return _vanished


func copy() -> SideBetView:
	var view: SideBetView = SideBetView.new()
	view._seen = _seen.duplicate()
	view._believed = _believed.duplicate()
	view._vanished = _vanished.duplicate()
	return view
