class_name Deck
extends RefCounted
## The deck the player owns for the whole run (spec §4). Its order never
## matters: each hand deals shuffled copies. Permanent changes go through
## here and are recorded as edits; temporary ones live in a ManipulationLayer.

var min_size: int

var _cards: Array[Card] = []
var _edits: Array[DeckEdit] = []
var _next_id: int = 0


func _init(p_min_size: int) -> void:
	min_size = p_min_size


static func standard(p_min_size: int) -> Deck:
	var deck: Deck = Deck.new(p_min_size)
	for suit: int in Card.Suit.values():
		for rank: int in range(1, 14):
			deck._append(Card.new(rank, suit as Card.Suit))
	return deck


func size() -> int:
	return _cards.size()


## Copies of every card, in deck order.
func cards() -> Array[Card]:
	var result: Array[Card] = []
	for card: Card in _cards:
		result.append(card.copy())
	return result


## A copy of the card with this id, or null.
func card(id: int) -> Card:
	var index: int = _index_of(id)
	return _cards[index].copy() if index != -1 else null


## Count of each card code, e.g. {"AS": 1, "10H": 2}.
func composition() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for owned: Card in _cards:
		var code: String = owned.short_name()
		counts[code] = counts.get(code, 0) + 1
	return counts


## Copies of every card as they read under layer, ready to shuffle and deal.
func dealing_cards(layer: ManipulationLayer) -> Array[Card]:
	var result: Array[Card] = []
	for owned: Card in _cards:
		result.append(layer.apply_to(owned))
	return result


func edits() -> Array[DeckEdit]:
	return _edits.duplicate()


func edit_count(kind: DeckEdit.Kind) -> int:
	var count: int = 0
	for edit: DeckEdit in _edits:
		if edit.kind == kind:
			count += 1
	return count


## False if the card is missing or the deck is at its minimum size.
func remove_card(id: int) -> bool:
	var index: int = _index_of(id)
	if index == -1 or _cards.size() <= min_size:
		return false
	_cards.remove_at(index)
	_edits.append(DeckEdit.new(DeckEdit.Kind.REMOVE, id))
	return true


## The new card (a copy), or null on a bad rank.
func add_card(rank: int, suit: Card.Suit) -> Card:
	if not Card.is_valid_rank(rank):
		push_error("Deck.add_card: bad rank %d" % rank)
		return null
	var added: Card = _append(Card.new(rank, suit))
	_edits.append(DeckEdit.new(DeckEdit.Kind.ADD, added.id))
	return added.copy()


## Permanently rewrites a card at a shop or event (spec §4.1). tier is one of
## DeckEdit.REFORGE_KINDS. What each tier may change is the shop's rule.
func reforge(id: int, rank: int, suit: Card.Suit, tier: DeckEdit.Kind) -> bool:
	if tier not in DeckEdit.REFORGE_KINDS:
		push_error("Deck.reforge: %s is not a reforge tier" % DeckEdit.Kind.keys()[tier])
		return false
	return _rewrite(id, rank, suit, tier)


## A manipulation made permanent by Permanent Ink (spec §9).
func ink(id: int, rank: int, suit: Card.Suit) -> bool:
	return _rewrite(id, rank, suit, DeckEdit.Kind.PERMANENT_INK)


## Applies symbol to the card, overwriting any old one (spec §4.3).
func mark(id: int, symbol: int) -> bool:
	var index: int = _index_of(id)
	if index == -1 or symbol < 0:
		return false
	_cards[index].symbol = symbol
	return true


func clear_mark(id: int) -> bool:
	var index: int = _index_of(id)
	if index == -1 or not _cards[index].is_marked():
		return false
	_cards[index].symbol = Card.NO_SYMBOL
	return true


func marked_count() -> int:
	var count: int = 0
	for owned: Card in _cards:
		if owned.is_marked():
			count += 1
	return count


func _rewrite(id: int, rank: int, suit: Card.Suit, kind: DeckEdit.Kind) -> bool:
	var index: int = _index_of(id)
	if index == -1 or not Card.is_valid_rank(rank):
		return false
	_cards[index].rank = rank
	_cards[index].suit = suit
	_edits.append(DeckEdit.new(kind, id))
	return true


func _append(new_card: Card) -> Card:
	new_card.id = _next_id
	_next_id += 1
	_cards.append(new_card)
	return new_card


func _index_of(id: int) -> int:
	for i: int in _cards.size():
		if _cards[i].id == id:
			return i
	return -1
