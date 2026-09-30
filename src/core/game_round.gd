# gdlint: disable=max-public-methods
# The shared round interface plus side bets pass the method cap.
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
## The side bets riding this hand (spec §8), placed before the deal.
var side_bets: Array[SideBet] = []

var _bet_locked: bool = false
## This adjust phase's bet change, or null: every adjust in one phase folds
## into it (spec §1.1).
var _phase_adjust: BetChange
## The window whose adjust _phase_adjust belongs to.
var _phase_adjust_window: int = 0
## Cards still to deal, front first.
var _pile: Array[Card]
var _side_rules: SideBetRules


func _init(p_limits: BetLimits, pile: Array[Card]) -> void:
	limits = p_limits
	opening_bet = p_limits.opening
	_pile = pile.duplicate()


## Deals the opening cards. Each game fills this in.
func deal() -> void:
	pass


## Puts copies of bets on this hand, replacing any placed before. Refused
## once cards are dealt: side bets go on at the stake window only (§8).
func place_side_bets(rules: SideBetRules, bets: Array[SideBet]) -> bool:
	if not _dealt_cards().is_empty():
		return false
	_side_rules = rules
	side_bets.clear()
	for bet: SideBet in bets:
		side_bets.append(bet.copy())
	return true


func has_side_bet(kind: SideBetKind.Kind) -> bool:
	return side_bets.any(func(bet: SideBet) -> bool: return bet.kind == kind)


## Dollars won (positive) or lost (negative) on side bets. 0 until settled.
func side_net() -> int:
	var total: int = 0
	for bet: SideBet in side_bets:
		total += bet.net()
	return total


## The bet's value (§8): its expected net in dollars from what the player
## can see. seen holds the ids of cards the player has seen that aren't face
## up (revealed, looked ahead at, or palmed).
func side_bet_value(bet: SideBet, seen: Dictionary[int, bool]) -> float:
	if is_resolved():
		return float(bet.net())
	return _side_bet_value(bet, seen)


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


## Raises or lowers the bet to new_total. Does nothing outside an adjust,
## past a limit, or without a change. One adjust phase is one bet change, its
## net: adjusting again folds in, and moving back to the start removes it.
func adjust(new_total: int) -> void:
	if not can_adjust() or new_total < adjust_min() or new_total > adjust_max():
		return
	var amount: int = new_total - total_bet()
	if amount == 0:
		return
	_apply_adjust(amount)
	var hand: int = _adjust_hand_index()
	if (
		_phase_adjust != null
		and _phase_adjust_window == window_number
		and _phase_adjust.hand_index == hand
	):
		_phase_adjust.amount += amount
		if _phase_adjust.amount == 0:
			bet_changes.erase(_phase_adjust)
			_phase_adjust = null
		return
	_phase_adjust = BetChange.new(BetChange.Kind.ADJUST, amount, hand)
	_phase_adjust_window = window_number
	bet_changes.append(_phase_adjust)


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


## Each game calls this as the round resolves: side bets read the cards as
## they read now.
func _settle_side_bets() -> void:
	for bet: SideBet in side_bets:
		bet.pays = _side_bet_pays(bet)


## What bet pays on this round's cards. Each game with side bets fills it in.
func _side_bet_pays(_bet: SideBet) -> int:
	push_error("GameRound._side_bet_pays: not implemented")
	return SideBetPayout.LOSE


## True for a card face up on the table now.
func is_face_up(card: Card) -> bool:
	return card in _face_up()


## By default a bet reads only face-up cards, so it's worth what it pays now.
func _side_bet_value(bet: SideBet, _seen: Dictionary[int, bool]) -> float:
	return SideBetValue.of_pays(bet, _side_bet_pays(bet))


## The cards face up on the table now. Each game fills it in.
func _face_up() -> Array[Card]:
	return []


## card if the player can see it, else null.
func _as_seen(card: Card, seen: Dictionary[int, bool]) -> Card:
	return card if seen.has(card.id) or card in _face_up() else null


## Every card of the hand the player hasn't seen: dealt cards neither face up
## nor seen, and pile cards not in pinned. A seen pile card stays in unless
## the bet's sequence pins it to its place.
func _unseen(seen: Dictionary[int, bool], pinned: Array[Card]) -> Array[Card]:
	var pool: Array[Card] = []
	var up: Array[Card] = _face_up()
	for card: Card in _dealt_cards():
		if card not in up and not seen.has(card.id):
			pool.append(card)
	for card: Card in _pile:
		if card not in pinned:
			pool.append(card)
	return pool


## Each game calls this when a window opens.
func _count_window() -> void:
	window_number += 1
