class_name DeckServices
extends RefCounted
## Deck services at a shop (spec §4.1): remove a card, add a specific card,
## and clear marks. Prices are shares of the floor quota, paid from
## bankroll, which the caller reads back. A service that can't be bought
## (unaffordable, or its card not allowed) is refused without charging. Each
## change is a deck edit and raises the heat floor (§4.2); clearing a mark
## lowers it.

enum Service { REMOVE, ADD, CLEAR_MARK }

var bankroll: int

var _rules: DeckRules
var _deck: Deck
var _kit: ActionKit
var _quota: int


func _init(rules: DeckRules, deck: Deck, kit: ActionKit, quota: int, p_bankroll: int) -> void:
	_rules = rules
	_deck = deck
	_kit = kit
	_quota = quota
	bankroll = p_bankroll


func price(service: Service) -> int:
	var pct: int = 0
	match service:
		Service.REMOVE:
			pct = _rules.removal_pct
			if not _kit.flat_removals:
				pct += _rules.removal_step_pct * _deck.edit_count(DeckEdit.Kind.REMOVE)
		Service.ADD:
			pct = _rules.addition_pct
		Service.CLEAR_MARK:
			pct = _rules.clear_mark_pct
	return Money.apply_ratio(_quota, pct, 100)


## Removals stop at the deck's minimum size (§4.1).
func can_remove(id: int) -> bool:
	return (
		_can_afford(Service.REMOVE)
		and _deck.card(id) != null
		and _deck.size() > _deck.min_size
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


func can_clear_mark(id: int) -> bool:
	var card: Card = _deck.card(id)
	return _can_afford(Service.CLEAR_MARK) and card != null and card.is_marked()


func clear_mark(id: int) -> bool:
	if not can_clear_mark(id):
		return false
	_pay(Service.CLEAR_MARK)
	return _deck.clear_mark(id)


func _can_afford(service: Service) -> bool:
	return bankroll >= price(service)


func _pay(service: Service) -> void:
	bankroll -= price(service)
