class_name BlackjackEv
extends RefCounted
## The bots' blackjack strategy (spec §12, "basic strategy"): the expected
## value of each play under the table's own rules (§3.1: the bust threshold,
## the dealer's stand rule, no peek, so a dealer natural beats every stake).
##
## Each card is drawn independently with the deck's odds (an infinite deck
## with the deck's composition), which is what a player can know once the
## deck reshuffles every hand. The dealer's hole card has its own odds, so a
## bot that revealed or narrowed it passes those instead. Values are per unit
## of the hand's stake. Splits are valued one level deep, with doubling after
## the split allowed.

enum Play { STAND, HIT, DOUBLE, SPLIT }

## Card values 1 (ace) to 10 (ten-value cards); odds arrays are indexed by
## value, index 0 unused.
const VALUES: int = 10
const ACE_BONUS: int = 10
## Aces beyond this never change a total at any sane bust threshold.
const MAX_ACES: int = 3

var _rules: BlackjackRules
var _odds: Array[float] = []
## Dealer outcomes from a hand state, drawing to the stand rule.
var _dealer_memo: Dictionary[int, Array] = {}
## Per dealer situation, the best of stand and hit from each player state.
var _best_memo: Dictionary[String, Dictionary] = {}


func _init(rules: BlackjackRules, odds: Array[float]) -> void:
	_rules = rules
	_odds = odds


## Odds from the composition of cards.
static func from_cards(rules: BlackjackRules, cards: Array[Card]) -> BlackjackEv:
	var odds: Array[float] = []
	odds.resize(VALUES + 1)
	odds.fill(0.0)
	for card: Card in cards:
		odds[value_of(card)] += 1.0 / cards.size()
	return BlackjackEv.new(rules, odds)


## Odds for a card known to be this one.
static func known(card: Card) -> Array[float]:
	var odds: Array[float] = []
	odds.resize(VALUES + 1)
	odds.fill(0.0)
	odds[value_of(card)] = 1.0
	return odds


static func value_of(card: Card) -> int:
	return mini(card.rank, VALUES)


## The deck's odds of each card value.
func deck_odds() -> Array[float]:
	return _odds.duplicate()


## Dealer outcome arrays: final totals 0..max_total, then bust, then natural.
func bust_index() -> int:
	return _rules.max_total() + 1


func natural_index() -> int:
	return _rules.max_total() + 2


## The chance of each dealer outcome, given the up card and the hole card's
## odds.
func dealer_outcomes(up: Card, hole: Array[float]) -> Array[float]:
	var outcomes: Array[float] = _zeros()
	var up_value: int = value_of(up)
	for value: int in range(1, VALUES + 1):
		var p: float = hole[value]
		if p <= 0.0:
			continue
		if (up_value == 1 and value == VALUES) or (up_value == VALUES and value == 1):
			outcomes[natural_index()] += p
			continue
		var aces: int = int(up_value == 1) + int(value == 1)
		var from_here: Array = _dealer_from(up_value + value, aces)
		for i: int in outcomes.size():
			var q: float = from_here[i]
			outcomes[i] += p * q
	return outcomes


## Standing on total, per unit stake.
func stand_value(total: int, up: Card, hole: Array[float]) -> float:
	return _stand(total, dealer_outcomes(up, hole))


## The value of each play the hand may make now.
func play_values(
	cards: Array[Card], up: Card, hole: Array[float], can_double: bool, can_split: bool
) -> Dictionary[Play, float]:
	var outcomes: Array[float] = dealer_outcomes(up, hole)
	var memo: Dictionary = _memo_for(up, hole)
	var hard: int = 0
	var aces: int = 0
	for card: Card in cards:
		hard += value_of(card)
		aces += int(card.is_ace())
	var values: Dictionary[Play, float] = {
		Play.STAND: _stand(_total(hard, aces), outcomes),
		Play.HIT: _hit(hard, aces, outcomes, memo),
	}
	if can_double and cards.size() == 2:
		values[Play.DOUBLE] = _double(hard, aces, outcomes)
	if can_split and cards.size() == 2 and cards[0].rank == cards[1].rank:
		values[Play.SPLIT] = _split(value_of(cards[0]), outcomes, memo)
	return values


## The best play; a tie goes to the earlier of stand, hit, double, split.
func decide(
	cards: Array[Card], up: Card, hole: Array[float], can_double: bool, can_split: bool
) -> Play:
	var values: Dictionary[Play, float] = play_values(cards, up, hole, can_double, can_split)
	var best: Play = Play.STAND
	for play: Play in values:
		if values[play] > values[best] + 1e-12:
			best = play
	return best


## The value of the best play.
func hand_value(
	cards: Array[Card], up: Card, hole: Array[float], can_double: bool, can_split: bool
) -> float:
	var values: Dictionary[Play, float] = play_values(cards, up, hole, can_double, can_split)
	return values[decide(cards, up, hole, can_double, can_split)]


func _stand(total: int, outcomes: Array[float]) -> float:
	if total >= _rules.bust_threshold:
		return -1.0
	var value: float = outcomes[bust_index()] - outcomes[natural_index()]
	for dealer_total: int in range(0, _rules.max_total() + 1):
		value += outcomes[dealer_total] * signf(total - dealer_total)
	return value


func _hit(hard: int, aces: int, outcomes: Array[float], memo: Dictionary) -> float:
	var value: float = 0.0
	for card: int in range(1, VALUES + 1):
		if _odds[card] > 0.0:
			value += _odds[card] * _best(hard + card, aces + int(card == 1), outcomes, memo)
	return value


## One card, then stand, at twice the stake.
func _double(hard: int, aces: int, outcomes: Array[float]) -> float:
	var value: float = 0.0
	for card: int in range(1, VALUES + 1):
		if _odds[card] > 0.0:
			value += _odds[card] * _stand(_total(hard + card, aces + int(card == 1)), outcomes)
	return 2.0 * value


## Two hands, each the pair card plus one, each free to double.
func _split(pair: int, outcomes: Array[float], memo: Dictionary) -> float:
	var value: float = 0.0
	for card: int in range(1, VALUES + 1):
		if _odds[card] <= 0.0:
			continue
		var hard: int = pair + card
		var aces: int = int(pair == 1) + int(card == 1)
		var best: float = maxf(_best(hard, aces, outcomes, memo), _double(hard, aces, outcomes))
		value += _odds[card] * best
	return 2.0 * value


## The better of standing and hitting on, from this state.
func _best(hard: int, aces: int, outcomes: Array[float], memo: Dictionary) -> float:
	aces = mini(aces, MAX_ACES)
	if hard >= _rules.bust_threshold:
		return -1.0
	var key: int = hard * (MAX_ACES + 1) + aces
	if memo.has(key):
		var cached: float = memo[key]
		return cached
	var stand: float = _stand(_total(hard, aces), outcomes)
	var best: float = maxf(stand, _hit(hard, aces, outcomes, memo))
	memo[key] = best
	return best


func _dealer_from(hard: int, aces: int) -> Array:
	aces = mini(aces, MAX_ACES)
	var key: int = hard * (MAX_ACES + 1) + aces
	if _dealer_memo.has(key):
		return _dealer_memo[key]
	var outcomes: Array[float] = _zeros()
	var total: int = _total(hard, aces)
	if total >= _rules.bust_threshold:
		outcomes[bust_index()] = 1.0
	elif not _dealer_hits(total, total != hard):
		outcomes[total] = 1.0
	else:
		for card: int in range(1, VALUES + 1):
			if _odds[card] <= 0.0:
				continue
			var next: Array = _dealer_from(hard + card, aces + int(card == 1))
			for i: int in outcomes.size():
				var q: float = next[i]
				outcomes[i] += _odds[card] * q
	_dealer_memo[key] = outcomes
	return outcomes


## Mirrors BlackjackRound: below the stand total, or on a soft stand total
## when the dealer hits soft 17.
func _dealer_hits(total: int, soft: bool) -> bool:
	if total < _rules.dealer_stand:
		return true
	return total == _rules.dealer_stand and soft and _rules.dealer_hits_soft_17


## Mirrors BlackjackHand: each ace counts 11 while the total stays unbust.
func _total(hard: int, aces: int) -> int:
	var total: int = hard
	for i: int in aces:
		if total + ACE_BONUS > _rules.max_total():
			break
		total += ACE_BONUS
	return total


func _memo_for(up: Card, hole: Array[float]) -> Dictionary:
	var key: String = "%d|%s" % [value_of(up), str(hole)]
	if not _best_memo.has(key):
		_best_memo[key] = {}
	return _best_memo[key]


func _zeros() -> Array[float]:
	var zeros: Array[float] = []
	zeros.resize(natural_index() + 1)
	zeros.fill(0.0)
	return zeros
