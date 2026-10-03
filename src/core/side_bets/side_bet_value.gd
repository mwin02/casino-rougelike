class_name SideBetValue
extends RefCounted
## A side bet's value (spec §8, side-bet heat): its expected net in dollars
## from what the player can see. A round lays out the cards a bet reads in
## deal order, each one seen or null for one the player can't see, plus the
## pool: every card of the hand the player hasn't seen. Unseen cards are
## drawn from the pool without replacement, by value.

## Blackjack values 1–10 (ace 1) and baccarat values 0–9: both ten buckets.
const BUCKETS: int = 11
## Per unit staked, when a bet loses.
const LOST: float = -1.0


static func of_pays(bet: SideBet, pays: int) -> float:
	return float(SideBetPayout.net(bet.stake, pays))


## The dealer's cards in order (up card first), then the dealer's draws.
static func bust_it(
	rules: SideBetRules,
	blackjack: BlackjackRules,
	bet: SideBet,
	sequence: Array[Card],
	pool: Array[Card]
) -> float:
	var counts: Array[int] = _counts(pool, _blackjack_value)
	var walk: Array = [rules, blackjack, sequence]
	return bet.stake * _bust_it_from(walk, 0, 0, 0, counts, pool.size())


## P1, B1, P2, B2, then the third cards in the order they come.
static func dragon_bonus(
	rules: SideBetRules, bet: SideBet, sequence: Array[Card], pool: Array[Card]
) -> float:
	var counts: Array[int] = _counts(pool, BaccaratHand.value)
	var values: Array[int] = []
	return bet.stake * _dragon_from([rules, bet.side, sequence], values, counts, pool.size())


## walk: [SideBetRules, BlackjackRules, sequence]. Returns net per unit.
static func _bust_it_from(
	walk: Array, index: int, hard: int, aces: int, counts: Array[int], left: int
) -> float:
	var rules: SideBetRules = walk[0]
	var blackjack: BlackjackRules = walk[1]
	var sequence: Array[Card] = walk[2]
	if index >= 2:
		var soft: bool = aces > 0 and hard + BlackjackHand.ACE_BONUS < blackjack.bust_threshold
		var total: int = hard + (BlackjackHand.ACE_BONUS if soft else 0)
		if index == 2 and total == 21:
			return LOST
		var bust: bool = total >= blackjack.bust_threshold
		if bust or not blackjack.dealer_hits_total(total, soft):
			return float(SideBetPayout.net(1, SideBetPayout.bust_it_on(rules, bust, index)))
	if index < sequence.size() and sequence[index] != null:
		var value: int = _blackjack_value(sequence[index])
		return _bust_it_from(walk, index + 1, hard + value, aces + int(value == 1), counts, left)
	if left == 0:
		return LOST
	var result: float = 0.0
	for value: int in range(1, BUCKETS):
		if counts[value] == 0:
			continue
		var weight: float = float(counts[value]) / left
		counts[value] -= 1
		result += weight * _bust_it_from(
			walk, index + 1, hard + value, aces + int(value == 1), counts, left - 1
		)
		counts[value] += 1
	return result


## walk: [SideBetRules, side, sequence]. Returns net per unit.
static func _dragon_from(walk: Array, values: Array[int], counts: Array[int], left: int) -> float:
	if _baccarat_done(values):
		var rules: SideBetRules = walk[0]
		var side: BaccaratRound.BetSide = walk[1]
		return float(SideBetPayout.net(1, _dragon_pays(rules, side, values)))
	var sequence: Array[Card] = walk[2]
	var index: int = values.size()
	if index < sequence.size() and sequence[index] != null:
		values.append(BaccaratHand.value(sequence[index]))
		var known: float = _dragon_from(walk, values, counts, left)
		values.pop_back()
		return known
	if left == 0:
		return LOST
	var result: float = 0.0
	for value: int in range(BUCKETS - 1):
		if counts[value] == 0:
			continue
		var weight: float = float(counts[value]) / left
		counts[value] -= 1
		values.append(value)
		result += weight * _dragon_from(walk, values, counts, left - 1)
		values.pop_back()
		counts[value] += 1
	return result


## values: P1, B1, P2, B2, then third cards. True once the tableau is done.
static func _baccarat_done(values: Array[int]) -> bool:
	if values.size() < 4:
		return false
	var player: int = (values[0] + values[2]) % 10
	var banker: int = (values[1] + values[3]) % 10
	if player >= BaccaratHand.NATURAL_MIN or banker >= BaccaratHand.NATURAL_MIN:
		return true
	if not BaccaratRules.player_draws(player):
		return values.size() >= 5 or not BaccaratRules.banker_draws(banker, BaccaratRules.NO_THIRD)
	if values.size() < 5:
		return false
	return values.size() >= 6 or not BaccaratRules.banker_draws(banker, values[4])


static func _dragon_pays(
	rules: SideBetRules, side: BaccaratRound.BetSide, values: Array[int]
) -> int:
	var player: int = values[0] + values[2]
	var banker: int = values[1] + values[3]
	var natural: bool = (
		player % 10 >= BaccaratHand.NATURAL_MIN or banker % 10 >= BaccaratHand.NATURAL_MIN
	)
	if values.size() > 4:
		if BaccaratRules.player_draws(player % 10):
			player += values[4]
			if values.size() == 6:
				banker += values[5]
		else:
			banker += values[4]
	return SideBetPayout.dragon_bonus(rules, side, player % 10, banker % 10, natural)


static func _counts(pool: Array[Card], value_of: Callable) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(BUCKETS)
	counts.fill(0)
	for card: Card in pool:
		var value: int = value_of.call(card)
		counts[value] += 1
	return counts


static func _blackjack_value(card: Card) -> int:
	return mini(card.rank, 10)
