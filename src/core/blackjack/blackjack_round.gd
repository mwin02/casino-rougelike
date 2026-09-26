class_name BlackjackRound
extends RefCounted
## One blackjack round: deal, hit, stand, resolve. No splits, doubles,
## insurance or windows yet (block 2). Cards come off the front of the pile.

enum State { READY, PLAYER_TURN, RESOLVED }
enum Outcome { NONE, NATURAL, WIN, LOSE, PUSH, PLAYER_BUST, DEALER_BUST }

var player_hand: BlackjackHand
var dealer_hand: BlackjackHand
var state: State = State.READY
var outcome: Outcome = Outcome.NONE
var bet: int

var _rules: BlackjackRules
var _pile: Array[Card]


func _init(rules: BlackjackRules, p_bet: int, pile: Array[Card]) -> void:
	_rules = rules
	bet = p_bet
	_pile = pile.duplicate()
	player_hand = BlackjackHand.new(rules)
	dealer_hand = BlackjackHand.new(rules)


## Player, dealer up, player, dealer hole. A player natural resolves at once.
func deal() -> void:
	if state != State.READY:
		return
	player_hand.add(_draw())
	dealer_hand.add(_draw())
	player_hand.add(_draw())
	dealer_hand.add(_draw())
	state = State.PLAYER_TURN
	if player_hand.is_natural():
		_resolve(Outcome.PUSH if dealer_hand.is_natural() else Outcome.NATURAL)


func hit() -> void:
	if state != State.PLAYER_TURN:
		return
	player_hand.add(_draw())
	if player_hand.is_bust():
		_resolve(Outcome.PLAYER_BUST)


func stand() -> void:
	if state != State.PLAYER_TURN:
		return
	if dealer_hand.is_natural():
		_resolve(Outcome.LOSE)
		return
	while _dealer_should_hit():
		dealer_hand.add(_draw())
	_resolve(_compare())


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	match outcome:
		Outcome.NATURAL:
			return Money.apply_ratio(bet, _rules.natural_payout_num, _rules.natural_payout_den)
		Outcome.WIN, Outcome.DEALER_BUST:
			return bet
		Outcome.LOSE, Outcome.PLAYER_BUST:
			return -bet
	return 0


func _dealer_should_hit() -> bool:
	var dealer_total: int = dealer_hand.total()
	if dealer_total < _rules.dealer_stand:
		return true
	return dealer_total == _rules.dealer_stand and dealer_hand.is_soft() and _rules.dealer_hits_soft_17


func _compare() -> Outcome:
	if dealer_hand.is_bust():
		return Outcome.DEALER_BUST
	var player_total: int = player_hand.total()
	var dealer_total: int = dealer_hand.total()
	if player_total > dealer_total:
		return Outcome.WIN
	if player_total < dealer_total:
		return Outcome.LOSE
	return Outcome.PUSH


func _resolve(result: Outcome) -> void:
	outcome = result
	state = State.RESOLVED


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	return card
