class_name BaccaratOdds
extends RefCounted
## Baccarat outcome odds from the cards showing (spec §3.2): every card not
## yet seen is drawn with the deck's odds (an infinite deck with the deck's
## composition), and the draws follow the fixed tableau in BaccaratRules.

## Indices into an outcomes array.
const PLAYER: int = 0
const BANKER: int = 1
const TIE: int = 2
## Baccarat card values 0–9.
const VALUES: int = 10


## The chance of each card value, 0 to 9, in cards.
static func value_odds(cards: Array[Card]) -> Array[float]:
	var odds: Array[float] = []
	odds.resize(VALUES)
	odds.fill(0.0)
	for card: Card in cards:
		odds[BaccaratHand.value(card)] += 1.0 / cards.size()
	return odds


## [P(player), P(banker), P(tie)] given the values showing on each side, in
## deal order. A side with fewer than two values has unseen second cards.
## natural_min is BaccaratRules.natural_min.
static func outcomes(
	player: Array[int], banker: Array[int], odds: Array[float], natural_min: int
) -> Array[float]:
	var result: Array[float] = [0.0, 0.0, 0.0]
	_play(player, banker, [odds, natural_min], 1.0, result)
	return result


## Per unit staked on side: +1 a win (a banker win less the commission), −1
## a loss, a tie pushes. A tie bet pays the tie payout.
static func side_value(
	odds_of: Array[float], side: BaccaratRound.BetSide, rules: BaccaratRules
) -> float:
	match side:
		BaccaratRound.BetSide.PLAYER:
			return odds_of[PLAYER] - odds_of[BANKER]
		BaccaratRound.BetSide.BANKER:
			var commission: float = rules.banker_commission_pct / 100.0
			return odds_of[BANKER] * (1.0 - commission) - odds_of[PLAYER]
	var tie_pays: float = float(rules.tie_payout_num) / rules.tie_payout_den
	return odds_of[TIE] * tie_pays - (1.0 - odds_of[TIE])


## deal: [odds, natural_min].
static func _play(
	player: Array[int], banker: Array[int], deal: Array, weight: float, result: Array[float]
) -> void:
	var natural_min: int = deal[1]
	if player.size() < 2:
		_each_card(player, banker, true, deal, weight, result)
		return
	if banker.size() < 2:
		_each_card(player, banker, false, deal, weight, result)
		return
	var player_total: int = _total(player)
	var banker_total: int = _total(banker)
	var two_each: bool = player.size() == 2 and banker.size() == 2
	var natural: bool = player_total >= natural_min or banker_total >= natural_min
	if not (two_each and natural):
		if player.size() == 2 and banker.size() == 2 and BaccaratRules.player_draws(player_total):
			_each_card(player, banker, true, deal, weight, result)
			return
		var third: int = player[2] if player.size() == 3 else BaccaratRules.NO_THIRD
		if banker.size() == 2 and BaccaratRules.banker_draws(banker_total, third):
			_each_card(player, banker, false, deal, weight, result)
			return
	if player_total > banker_total:
		result[PLAYER] += weight
	elif banker_total > player_total:
		result[BANKER] += weight
	else:
		result[TIE] += weight


## Deals each value to one side, weighted by its odds.
static func _each_card(
	player: Array[int],
	banker: Array[int],
	to_player: bool,
	deal: Array,
	weight: float,
	result: Array[float]
) -> void:
	var odds: Array[float] = deal[0]
	for value: int in VALUES:
		if odds[value] <= 0.0:
			continue
		var next: Array[int] = (player if to_player else banker).duplicate()
		next.append(value)
		if to_player:
			_play(next, banker, deal, weight * odds[value], result)
		else:
			_play(player, next, deal, weight * odds[value], result)


static func _total(values: Array[int]) -> int:
	var sum: int = 0
	for value: int in values:
		sum += value
	return sum % 10
