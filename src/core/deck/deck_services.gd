class_name DeckServices
extends RefCounted
## Deck services at a shop (spec §4.1): remove a card, add a specific card,
## reforge at one of three tiers, and clear marks. Prices are shares of the
## floor quota, paid from bankroll, which the caller reads back. A service
## that can't be bought (unaffordable, or its card or change not allowed) is
## refused without charging. Each change is a deck edit and raises the heat
## floor (§4.2); clearing a mark lowers it.
##
## Rummage is paid when its cards are shown. The player then makes one small
## change to one of them, or skips and loses the money. Events that offer a
## tier cheaper or free can reforge through Deck directly.

enum Service { REMOVE, ADD, RUMMAGE, TOUCH_UP, FULL_REFORGE, CLEAR_MARK }

var bankroll: int

var _rules: DeckRules
var _deck: Deck
var _kit: ActionKit
var _quota: int
var _rng: RandomNumberGenerator
## The open Rummage's card ids, empty when none is open.
var _offer: Array[int] = []


func _init(
	rules: DeckRules,
	deck: Deck,
	kit: ActionKit,
	quota: int,
	p_bankroll: int,
	rng: RandomNumberGenerator
) -> void:
	_rules = rules
	_deck = deck
	_kit = kit
	_quota = quota
	bankroll = p_bankroll
	_rng = rng


## A small change is a move of at most step ranks, no wrap, or a new suit;
## not both, and not the same card.
static func is_small_change(card: Card, rank: int, suit: Card.Suit, step: int) -> bool:
	if not Card.is_valid_rank(rank):
		return false
	if suit == card.suit:
		return rank != card.rank and absi(rank - card.rank) <= step
	return rank == card.rank


func price(service: Service) -> int:
	var pct: int = 0
	match service:
		Service.REMOVE:
			pct = _rules.removal_pct
			if not _kit.flat_removals:
				pct += _rules.removal_step_pct * _deck.edit_count(DeckEdit.Kind.REMOVE)
		Service.ADD:
			pct = _rules.addition_pct
		Service.RUMMAGE:
			pct = _rules.rummage_pct
		Service.TOUCH_UP:
			pct = _rules.touch_up_pct
		Service.FULL_REFORGE:
			pct = _rules.full_reforge_pct
		Service.CLEAR_MARK:
			pct = _rules.clear_mark_pct
	return Money.apply_ratio(_quota, pct, 100)


## Removals stop at the deck's minimum size (§4.1). A card an open
## Rummage shows stays until the Rummage closes.
func can_remove(id: int) -> bool:
	return (
		_can_afford(Service.REMOVE)
		and _deck.card(id) != null
		and _deck.size() > _deck.min_size
		and id not in _offer
	)


func remove(id: int) -> bool:
	if not can_remove(id):
		return false
	_pay(Service.REMOVE)
	return _deck.remove_card(id)


func can_add(rank: int) -> bool:
	return _can_afford(Service.ADD) and Card.is_valid_rank(rank)


func add(rank: int, suit: Card.Suit) -> bool:
	if not can_add(rank):
		return false
	_pay(Service.ADD)
	return _deck.add_card(rank, suit) != null


## Pays for a Rummage and shows its cards (copies), or returns none if one is
## already open or the player can't afford it.
func start_rummage() -> Array[Card]:
	if not _offer.is_empty() or not _can_afford(Service.RUMMAGE):
		return []
	_pay(Service.RUMMAGE)
	var shuffled: Array[Card] = CardShuffle.shuffled(_deck.cards(), _rng)
	for card: Card in shuffled.slice(0, _rules.rummage_cards):
		_offer.append(card.id)
	return rummage_offer()


## The open Rummage's cards (copies), or none.
func rummage_offer() -> Array[Card]:
	var result: Array[Card] = []
	for id: int in _offer:
		result.append(_deck.card(id))
	return result


## Makes the open Rummage's one change, which closes it.
func rummage(id: int, rank: int, suit: Card.Suit) -> bool:
	if not can_reforge(Service.RUMMAGE, id, rank, suit):
		return false
	_offer.clear()
	return _deck.reforge(id, rank, suit, DeckEdit.Kind.REFORGE_RUMMAGE)


## Closes the open Rummage without a change. Its price stays paid.
func skip_rummage() -> void:
	_offer.clear()


## Whether a reforge tier can turn the card with id into rank and suit:
## Rummage only on a shown card (already paid for), Touch-up a small change,
## Full reforge any change.
func can_reforge(service: Service, id: int, rank: int, suit: Card.Suit) -> bool:
	var card: Card = _deck.card(id)
	if card == null:
		return false
	var step: int = _rules.small_change_rank_step
	match service:
		Service.RUMMAGE:
			return id in _offer and is_small_change(card, rank, suit, step)
		Service.TOUCH_UP:
			return _can_afford(service) and is_small_change(card, rank, suit, step)
		Service.FULL_REFORGE:
			return (
				_can_afford(service)
				and Card.is_valid_rank(rank)
				and (rank != card.rank or suit != card.suit)
			)
	return false


func touch_up(id: int, rank: int, suit: Card.Suit) -> bool:
	return _buy_reforge(Service.TOUCH_UP, DeckEdit.Kind.REFORGE_TOUCH_UP, id, rank, suit)


func full_reforge(id: int, rank: int, suit: Card.Suit) -> bool:
	return _buy_reforge(Service.FULL_REFORGE, DeckEdit.Kind.REFORGE_FULL, id, rank, suit)


func can_clear_mark(id: int) -> bool:
	var card: Card = _deck.card(id)
	return _can_afford(Service.CLEAR_MARK) and card != null and card.is_marked()


func clear_mark(id: int) -> bool:
	if not can_clear_mark(id):
		return false
	_pay(Service.CLEAR_MARK)
	return _deck.clear_mark(id)


func _buy_reforge(
	service: Service, tier: DeckEdit.Kind, id: int, rank: int, suit: Card.Suit
) -> bool:
	if not can_reforge(service, id, rank, suit):
		return false
	_pay(service)
	return _deck.reforge(id, rank, suit, tier)


func _can_afford(service: Service) -> bool:
	return bankroll >= price(service)


func _pay(service: Service) -> void:
	bankroll -= price(service)
