class_name ServicesVM
extends RefCounted
## Deck services on screen (block U4, spec §4.1): pick a service, then a
## card and its change, see what it does to the heat floor and the bankroll,
## and pay. Rummage is paid when its cards are shown; then one of them takes
## a small change, or the money is lost. The deck-services node and the end
## shop both stand on it.

const NONE: int = -1
const SUIT_NAMES: Array[String] = ["Clubs", "Diamonds", "Hearts", "Spades"]
const VERBS: Dictionary[DeckServices.Service, String] = {
	DeckServices.Service.RUMMAGE: "Change",
	DeckServices.Service.TOUCH_UP: "Reforge",
	DeckServices.Service.FULL_REFORGE: "Reforge",
	DeckServices.Service.REMOVE: "Remove",
	DeckServices.Service.ADD: "Add",
	DeckServices.Service.CLEAR_MARK: "Clear mark",
}
const HINTS: Dictionary[DeckServices.Service, String] = {
	DeckServices.Service.RUMMAGE: "One small change to one of these, or skip and lose the fee.",
	DeckServices.Service.TOUCH_UP: "Any card in your deck, one small change: rank or suit, not both.",
	DeckServices.Service.FULL_REFORGE: "Any card in your deck into any other card. It keeps its mark.",
	DeckServices.Service.REMOVE: "The card leaves your deck for good.",
	DeckServices.Service.ADD: "Choose the card to add to your deck.",
	DeckServices.Service.CLEAR_MARK: "A marked card loses its mark, and its share of the heat floor.",
}
const SHOW_CARDS: String = "Show cards"
const PICK_A_SERVICE: String = "Pick a service"
const EDITS_NOTE: String = "deck edits raise the heat floor"
const PICK_HINT: String = "Every change to the deck raises the heat floor every table starts at."

var _owner: RunVM
var _run: Run
var _services: DeckServices
var _deck: Deck
var _rules: DeckRules
var _quota: int
## The service in progress, or NONE.
var _service: int = NONE
var _card_id: int = NONE
## The change's rank and suit; NONE until chosen.
var _rank: int = NONE
var _suit: int = NONE


## services is the open deck-services stop, or the end shop's.
func _init(owner: RunVM, services: DeckServices) -> void:
	_owner = owner
	_run = owner.run
	_services = services
	_deck = _run.game.deck
	_rules = DeckRules.from_config(_run.config())
	_quota = _run.floor.quota
	if rummage_open():
		_service = DeckServices.Service.RUMMAGE


func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


func money() -> ShopMoney:
	return ShopMoney.new(_services.bankroll, _quota)


## "DECK 52".
func deck_text() -> String:
	return "DECK %d" % _deck.size()


## "DECK 52 · deck edits raise the heat floor".
func deck_note() -> String:
	return "%s · %s" % [deck_text(), EDITS_NOTE]


func services() -> Array[ServiceRow]:
	return ServiceRow.list(_services, _deck, _run.kit, _rules, _service)


## True while a paid Rummage waits for its change.
func rummage_open() -> bool:
	return not _services.rummage_offer().is_empty()


## The service in progress, or NONE.
func selected() -> int:
	return _service


## Starts a service. Refused while a Rummage is open.
func select(service: DeckServices.Service) -> void:
	if rummage_open():
		return
	_service = service
	_clear_pick()
	if service == DeckServices.Service.ADD:
		_suit = Card.Suit.SPADES


## Puts the service away. An open Rummage is skipped, its fee lost.
func cancel() -> void:
	if rummage_open():
		_services.skip_rummage()
		_owner.step_done()
	_service = NONE
	_clear_pick()


## The cards to pick from, by suit then rank: the deck, or an open
## Rummage's cards. None for adding a card, or before a service is picked.
func cards() -> Array[CardView]:
	var views: Array[CardView] = []
	if _service in [NONE, DeckServices.Service.ADD]:
		return views
	var showing: Array[Card] = _deck.cards()
	if _service == DeckServices.Service.RUMMAGE:
		showing = _services.rummage_offer()
	for card: Card in showing:
		var view: CardView = CardView.new(card, false, false)
		view.dimmed = not can_pick(card.id)
		views.append(view)
	views.sort_custom(
		func(a: CardView, b: CardView) -> bool:
			return a.rank < b.rank if a.suit == b.suit else a.suit > b.suit
	)
	return views


func can_pick(id: int) -> bool:
	var card: Card = _deck.card(id)
	if card == null:
		return false
	match _service:
		DeckServices.Service.REMOVE:
			return _services.can_remove(id)
		DeckServices.Service.CLEAR_MARK:
			return card.is_marked()
		DeckServices.Service.RUMMAGE:
			return rummage_open()
		DeckServices.Service.TOUCH_UP, DeckServices.Service.FULL_REFORGE:
			return true
	return false


func pick_card(id: int) -> void:
	if not can_pick(id):
		return
	_clear_pick()
	_card_id = id
	if _service == DeckServices.Service.FULL_REFORGE:
		var card: Card = _deck.card(id)
		_rank = card.rank
		_suit = card.suit


func picked_id() -> int:
	return _card_id


## The ranks the change can take: one step either way for a small change,
## any rank for a full reforge or a new card.
func rank_options() -> Array[Choice]:
	var options: Array[Choice] = []
	var card: Card = _deck.card(_card_id)
	if not _changes() or (card == null and _service != DeckServices.Service.ADD):
		return options
	for rank: int in range(1, Card.RANK_CODES.size()):
		if not Card.is_valid_rank(rank):
			continue
		if _small() and (rank == card.rank or absi(rank - card.rank) > _rules.small_change_rank_step):
			continue
		options.append(Choice.new(Card.RANK_CODES[rank], true, rank, rank == _rank))
	return options


## The suits the change can take: the other three for a small change, all
## four otherwise.
func suit_options() -> Array[Choice]:
	var options: Array[Choice] = []
	var card: Card = _deck.card(_card_id)
	if not _changes() or (card == null and _service != DeckServices.Service.ADD):
		return options
	for suit: int in [Card.Suit.SPADES, Card.Suit.HEARTS, Card.Suit.CLUBS, Card.Suit.DIAMONDS]:
		if _small() and suit == card.suit:
			continue
		options.append(Choice.new(SUIT_NAMES[suit], true, suit, suit == _suit))
	return options


## A small change is rank or suit, not both: choosing one puts the other back.
func choose_rank(rank: int) -> void:
	_rank = rank
	if _small():
		_suit = _deck.card(_card_id).suit


func choose_suit(suit: int) -> void:
	_suit = suit
	if _small():
		_rank = _deck.card(_card_id).rank


func preview() -> ServicePreview:
	var view: ServicePreview = ServicePreview.new()
	view.title = PICK_A_SERVICE
	view.hint = PICK_HINT
	if _service == NONE:
		return view
	var service: DeckServices.Service = _service as DeckServices.Service
	var waiting: bool = service == DeckServices.Service.RUMMAGE and not rummage_open()
	view.title = "%s: %s" % [ServiceRow.NAMES[service], _next_step(waiting)]
	view.hint = HINTS[service]
	var card: Card = _deck.card(_card_id)
	if card != null:
		view.before = CardView.new(card, false, false)
	if _target_ready():
		var target: Card = Card.new(_rank, _suit as Card.Suit)
		if card != null:
			target.symbol = card.symbol
		view.after = CardView.new(target, false, false)
	var floor_now: float = HeatFloor.of(_deck, _run.kit, _rules)
	view.floor_before_text = str(roundi(floor_now))
	view.floor_after_text = str(roundi(_floor_after(floor_now)))
	view.confirm_label = SHOW_CARDS if waiting else VERBS[service]
	# An open Rummage is already paid for.
	var cost: int = 0 if rummage_open() else _services.price(service)
	view.price_text = "" if cost == 0 else MoneyFormat.format(cost)
	view.can_confirm = _can_confirm(waiting)
	view.after_text = _after_text(_services.bankroll - cost)
	return view


## The bankroll once paid, against the quota; at the end shop, where the
## quota is behind (§6.5), against the reserve instead.
func _after_text(left: int) -> String:
	var gap: String = MoneyFormat.format(maxi(left - _services.reserve, 0)) + " TO SPEND"
	if _services.reserve == 0:
		var after: ShopMoney = ShopMoney.new(left, _quota)
		gap = "QUOTA REACHED" if after.at_quota() else after.short_text(0) + " SHORT"
	return "BANKROLL %s · %s" % [MoneyFormat.format(left), gap]


## Pays for the service in progress and does it. The service stays picked
## for another card.
func confirm() -> void:
	var done: bool = false
	match _service:
		DeckServices.Service.RUMMAGE:
			if rummage_open():
				done = _services.rummage(_card_id, _rank, _suit as Card.Suit)
				if done:
					_service = NONE
			else:
				done = not _services.start_rummage().is_empty()
		DeckServices.Service.TOUCH_UP:
			done = _services.touch_up(_card_id, _rank, _suit as Card.Suit)
		DeckServices.Service.FULL_REFORGE:
			done = _services.full_reforge(_card_id, _rank, _suit as Card.Suit)
		DeckServices.Service.REMOVE:
			done = _services.remove(_card_id)
		DeckServices.Service.ADD:
			done = _target_ready() and _services.add(_rank, _suit as Card.Suit)
		DeckServices.Service.CLEAR_MARK:
			done = _services.clear_mark(_card_id)
	if done:
		_clear_pick()
		if _service == DeckServices.Service.ADD:
			_suit = Card.Suit.SPADES
		_owner.step_done()


## Leaves a deck-services stop for the map. An open Rummage is skipped.
func leave() -> void:
	cancel()
	if _run.floor.leave():
		_owner.step_done()


func _clear_pick() -> void:
	_card_id = NONE
	_rank = NONE
	_suit = NONE


## True for the services that turn a card into another, or add one.
func _changes() -> bool:
	if _service == DeckServices.Service.RUMMAGE:
		return rummage_open()
	return _service in [
		DeckServices.Service.TOUCH_UP, DeckServices.Service.FULL_REFORGE,
		DeckServices.Service.ADD,
	]


func _small() -> bool:
	return _service in [DeckServices.Service.RUMMAGE, DeckServices.Service.TOUCH_UP]


func _target_ready() -> bool:
	return _changes() and _rank != NONE and _suit != NONE


func _next_step(waiting: bool) -> String:
	if waiting:
		return "show %d cards" % _rules.rummage_cards
	if _service == DeckServices.Service.ADD:
		return "choose the card"
	if _card_id == NONE:
		return "pick a card"
	return "choose the change" if _changes() and not _can_confirm(false) else "confirm"


func _can_confirm(waiting: bool) -> bool:
	var service: DeckServices.Service = _service as DeckServices.Service
	if waiting:
		return _services.bankroll - _services.price(service) >= _services.reserve
	match service:
		DeckServices.Service.REMOVE:
			return _services.can_remove(_card_id)
		DeckServices.Service.CLEAR_MARK:
			return _services.can_clear_mark(_card_id)
		DeckServices.Service.ADD:
			return _target_ready() and _services.can_add(_rank)
	return _target_ready() and _services.can_reforge(
		service, _card_id, _rank, _suit as Card.Suit
	)


## The heat floor once the service in progress is done: worked on a copy of
## the deck, so it follows the rules' own sum.
func _floor_after(floor_now: float) -> float:
	if not _can_confirm(false) or _service == NONE:
		return floor_now
	var copy: Deck = Deck.from_dict(_deck.to_dict(), _deck.min_size)
	var suit: Card.Suit = maxi(_suit, 0) as Card.Suit
	match _service:
		DeckServices.Service.RUMMAGE:
			copy.reforge(_card_id, _rank, suit, DeckEdit.Kind.REFORGE_RUMMAGE)
		DeckServices.Service.TOUCH_UP:
			copy.reforge(_card_id, _rank, suit, DeckEdit.Kind.REFORGE_TOUCH_UP)
		DeckServices.Service.FULL_REFORGE:
			copy.reforge(_card_id, _rank, suit, DeckEdit.Kind.REFORGE_FULL)
		DeckServices.Service.REMOVE:
			copy.remove_card(_card_id)
		DeckServices.Service.ADD:
			copy.add_card(_rank, suit)
		DeckServices.Service.CLEAR_MARK:
			copy.clear_mark(_card_id)
	return HeatFloor.of(copy, _run.kit, _rules)
