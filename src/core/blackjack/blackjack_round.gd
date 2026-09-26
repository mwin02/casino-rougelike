class_name BlackjackRound
extends RefCounted
## One blackjack round (spec §3.1), with its windows as explicit phases.
## Cards come off the front of the pile.
##
## Deal, then the hole-card window and an adjust, then the player's turn. A hit
## or double opens a window on the incoming card and an adjust before the card
## is drawn. Standing opens the final window; passing it plays the dealer and
## resolves. proceed() closes the current window or adjust. Windows and
## adjusts take no actions yet (block 5). There is no peek: a dealer natural
## is found at resolution and beats every stake.

enum Phase { READY, WINDOW, ADJUST, PLAYER_TURN, RESOLVED }
enum WindowKind { NONE, HOLE_CARD, BEFORE_HIT, FINAL }
## The player draw waiting behind a window and adjust.
enum Pending { NONE, HIT, DOUBLE }

var hands: Array[BlackjackHand] = []
var active_hand_index: int = 0
var dealer_hand: BlackjackHand
var phase: Phase = Phase.READY
var window: WindowKind = WindowKind.NONE
## The stake placed at the stake window. Bet changes are measured against it.
var opening_bet: int
var bet_changes: Array[BetChange] = []

var _rules: BlackjackRules
var _pile: Array[Card]
var _pending: Pending = Pending.NONE
var _bet_locked: bool = false


func _init(rules: BlackjackRules, p_opening_bet: int, pile: Array[Card]) -> void:
	_rules = rules
	opening_bet = p_opening_bet
	_pile = pile.duplicate()
	var first: BlackjackHand = BlackjackHand.new(rules)
	first.stake = opening_bet
	hands.append(first)
	dealer_hand = BlackjackHand.new(rules)


func active_hand() -> BlackjackHand:
	return hands[active_hand_index]


## Player, dealer up, player, dealer hole. A player natural resolves at once.
func deal() -> void:
	if phase != Phase.READY:
		return
	var hand: BlackjackHand = active_hand()
	hand.add(_draw())
	dealer_hand.add(_draw())
	hand.add(_draw())
	dealer_hand.add(_draw())
	if hand.is_natural():
		var push: bool = dealer_hand.is_natural()
		hand.outcome = BlackjackHand.Outcome.PUSH if push else BlackjackHand.Outcome.NATURAL
		_enter(Phase.RESOLVED)
		return
	_enter(Phase.WINDOW, WindowKind.HOLE_CARD)


## Closes the current window or adjust.
func proceed() -> void:
	match phase:
		Phase.WINDOW:
			if window == WindowKind.FINAL:
				_play_dealer()
			else:
				_enter(Phase.ADJUST)
		Phase.ADJUST:
			if _pending == Pending.NONE:
				_enter(Phase.PLAYER_TURN)
			else:
				_draw_pending()


func can_hit() -> bool:
	return phase == Phase.PLAYER_TURN


func can_stand() -> bool:
	return can_hit()


## Doubling is a bet change, so a locked bet forbids it (spec §2.2).
func can_double() -> bool:
	return can_hit() and not _bet_locked and active_hand().cards.size() == 2


func hit() -> void:
	if can_hit():
		_open_draw(Pending.HIT)


func double() -> void:
	if not can_double():
		return
	var hand: BlackjackHand = active_hand()
	bet_changes.append(BetChange.new(BetChange.Kind.DOUBLE, hand.stake, active_hand_index))
	hand.stake *= 2
	hand.doubled = true
	_open_draw(Pending.DOUBLE)


func stand() -> void:
	if can_stand():
		active_hand().stood = true
		_next_hand()


## After a manipulation (spec §2.2): no more doubles, splits or insurance.
func lock_bet() -> void:
	_bet_locked = true


func is_bet_locked() -> bool:
	return _bet_locked


## Every dollar on the table now: all hands' stakes.
func total_bet() -> int:
	var total: int = 0
	for hand: BlackjackHand in hands:
		total += hand.stake
	return total


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	var total: int = 0
	for hand: BlackjackHand in hands:
		total += hand.net()
	return total


func _open_draw(pending: Pending) -> void:
	_pending = pending
	_enter(Phase.WINDOW, WindowKind.BEFORE_HIT)


func _draw_pending() -> void:
	var hand: BlackjackHand = active_hand()
	hand.add(_draw())
	if _pending == Pending.DOUBLE:
		hand.stood = true
	_pending = Pending.NONE
	if hand.is_done():
		_next_hand()
	else:
		_enter(Phase.PLAYER_TURN)


## Moves to the next unfinished hand, or on to the final window. With every
## hand bust there is nothing left to play for, so the round resolves.
func _next_hand() -> void:
	while active_hand_index < hands.size() - 1 and active_hand().is_done():
		active_hand_index += 1
	if not active_hand().is_done():
		_enter(Phase.PLAYER_TURN)
		return
	for hand: BlackjackHand in hands:
		if not hand.is_bust():
			_enter(Phase.WINDOW, WindowKind.FINAL)
			return
	_settle()


func _play_dealer() -> void:
	if not dealer_hand.is_natural():
		while _dealer_should_hit():
			dealer_hand.add(_draw())
	_settle()


func _dealer_should_hit() -> bool:
	var dealer_total: int = dealer_hand.total()
	if dealer_total < _rules.dealer_stand:
		return true
	return dealer_total == _rules.dealer_stand and dealer_hand.is_soft() and _rules.dealer_hits_soft_17


func _settle() -> void:
	for hand: BlackjackHand in hands:
		hand.outcome = _compare(hand)
	_enter(Phase.RESOLVED)


func _compare(hand: BlackjackHand) -> BlackjackHand.Outcome:
	if hand.is_bust():
		return BlackjackHand.Outcome.PLAYER_BUST
	if dealer_hand.is_natural():
		return BlackjackHand.Outcome.LOSE
	if dealer_hand.is_bust():
		return BlackjackHand.Outcome.DEALER_BUST
	var player_total: int = hand.total()
	var dealer_total: int = dealer_hand.total()
	if player_total > dealer_total:
		return BlackjackHand.Outcome.WIN
	if player_total < dealer_total:
		return BlackjackHand.Outcome.LOSE
	return BlackjackHand.Outcome.PUSH


func _enter(next_phase: Phase, next_window: WindowKind = WindowKind.NONE) -> void:
	phase = next_phase
	window = next_window


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	return card
