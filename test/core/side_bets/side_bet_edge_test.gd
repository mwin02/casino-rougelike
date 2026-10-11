extends GdUnitTestSuite
## Spec §8, §12: every side bet lands at a 5–15% house edge on a standard
## 52-card deck, by exact enumeration under the configured rules.

const MIN_EDGE: float = 0.05
const MAX_EDGE: float = 0.15
const RANKS: int = 13
## Baccarat values 0–9: tens and faces are 0.
const VALUES: int = 10

var _config: TuneConfig = TuneConfig.load_default()
var _rules: SideBetRules = SideBetRules.from_config(_config)
var _blackjack: BlackjackRules = BlackjackRules.from_config(_config)
var _baccarat: BaccaratRules = BaccaratRules.from_config(_config)
var _deck: Array[Card] = Deck.standard(0).cards()


func _assert_in_band(return_per_stake: float) -> void:
	# Return per unit staked is −edge.
	assert_float(-return_per_stake).is_between(MIN_EDGE, MAX_EDGE)


func _pays_back(pays: int) -> float:
	return float(SideBetPayout.net(1, pays))


func test_perfect_pairs_edge() -> void:
	_assert_in_band(_perfect_pairs_return(_rules))


func _perfect_pairs_return(rules: SideBetRules) -> float:
	var total: float = 0.0
	var hands: int = 0
	for i: int in _deck.size():
		for j: int in range(i + 1, _deck.size()):
			total += _pays_back(SideBetPayout.perfect_pairs(rules, _deck[i], _deck[j]))
			hands += 1
	return total / hands


func test_twenty_one_plus_three_edge() -> void:
	_assert_in_band(_twenty_one_plus_three_return(_rules))


func _twenty_one_plus_three_return(rules: SideBetRules) -> float:
	var total: float = 0.0
	var hands: int = 0
	var n: int = _deck.size()
	for i: int in n:
		for j: int in range(i + 1, n):
			for k: int in range(j + 1, n):
				var pays: int = SideBetPayout.twenty_one_plus_three(
					rules, _deck[i], _deck[j], _deck[k]
				)
				total += _pays_back(pays)
				hands += 1
	return total / hands


## Bust It is enumerated from the full deck, the dealer always playing out
## (§8). That is exact when the player takes no extra cards: the dealer's
## cards are then a uniform draw from all 52, whatever the player holds.
## Player hits depend on the cards, so the edge in play differs a little.
func test_bust_it_edge() -> void:
	var counts: Array[int] = []
	counts.resize(RANKS)
	counts.fill(4)
	_assert_in_band(_bust_it_return([_rules, _blackjack], [], counts, 52))


## Block 17: every blackjack house rule keeps each side bet in band, Bust It
## on its own pay table if the rule sets one, and the value engine prices it
## the same way.
func test_blackjack_side_bet_edges_under_each_house_rule() -> void:
	var none: Array[Card] = []
	var bust: SideBet = SideBet.new(SideBetKind.Kind.BUST_IT, 1)
	var checked: int = 0
	for name: String in _config.house_rules():
		if _config.house_rule_game(name) != GameKind.config_section(GameKind.Kind.BLACKJACK):
			continue
		checked += 1
		var config: TuneConfig = _config.for_house_rule(name)
		var side: SideBetRules = SideBetRules.from_config(config)
		var blackjack: BlackjackRules = BlackjackRules.from_config(config)
		var counts: Array[int] = []
		counts.resize(RANKS)
		counts.fill(4)
		var enumerated: float = _bust_it_return([side, blackjack], [], counts, 52)
		_assert_in_band(enumerated)
		assert_float(SideBetValue.bust_it(side, blackjack, bust, none, _deck)).is_equal_approx(
			enumerated, 0.000001
		)
		_assert_in_band(_perfect_pairs_return(side))
		_assert_in_band(_twenty_one_plus_three_return(side))
	assert_int(checked).is_greater(0)


## rules: [SideBetRules, BlackjackRules].
func _bust_it_return(rules: Array, ranks: Array[int], counts: Array[int], left: int) -> float:
	var side: SideBetRules = rules[0]
	var blackjack: BlackjackRules = rules[1]
	var hand: BlackjackHand = BlackjackHand.new(blackjack)
	for rank: int in ranks:
		hand.add(Card.new(rank, Card.Suit.SPADES))
	if ranks.size() >= 2 and (hand.is_bust() or not blackjack.dealer_hits(hand)):
		return _pays_back(SideBetPayout.bust_it(side, hand))
	var total: float = 0.0
	for index: int in RANKS:
		if counts[index] == 0:
			continue
		var weight: float = float(counts[index]) / left
		counts[index] -= 1
		var next: Array[int] = ranks.duplicate()
		next.append(index + 1)
		total += weight * _bust_it_return(rules, next, counts, left - 1)
		counts[index] += 1
	return total


func test_the_value_engine_agrees_with_the_enumeration() -> void:
	# SideBetValue (side-bet heat) with nothing seen, stake 1.
	var counts: Array[int] = []
	counts.resize(RANKS)
	counts.fill(4)
	var none: Array[Card] = []
	var bust: SideBet = SideBet.new(SideBetKind.Kind.BUST_IT, 1)
	assert_float(SideBetValue.bust_it(_rules, _blackjack, bust, none, _deck)).is_equal_approx(
		_bust_it_return([_rules, _blackjack], [], counts, 52), 0.000001
	)


func test_dragon_bonus_edge_on_both_sides() -> void:
	_check_dragon_bonus()


## Block 17: every baccarat house rule keeps Dragon Bonus and Pair in band,
## and the value engine prices Dragon Bonus the same way.
func test_baccarat_side_bet_edges_under_each_house_rule() -> void:
	var checked: int = 0
	for name: String in _config.house_rules():
		if _config.house_rule_game(name) != GameKind.config_section(GameKind.Kind.BACCARAT):
			continue
		checked += 1
		var config: TuneConfig = _config.for_house_rule(name)
		_rules = SideBetRules.from_config(config)
		_baccarat = BaccaratRules.from_config(config)
		_check_dragon_bonus()
		test_pair_edge()
	_rules = SideBetRules.from_config(_config)
	_baccarat = BaccaratRules.from_config(_config)
	assert_int(checked).is_greater(0)


## Enumerates Dragon Bonus under _rules and _baccarat.
func _check_dragon_bonus() -> void:
	var returns: Array[float] = [0.0, 0.0]
	var counts: Array[int] = [16, 4, 4, 4, 4, 4, 4, 4, 4, 4]
	var sides: Array[BaccaratRound.BetSide] = [
		BaccaratRound.BetSide.PLAYER, BaccaratRound.BetSide.BANKER
	]
	for p1: int in VALUES:
		var w1: float = _take(counts, p1, 52)
		for b1: int in VALUES:
			var w2: float = _take(counts, b1, 51)
			for p2: int in VALUES:
				var w3: float = _take(counts, p2, 50)
				for b2: int in VALUES:
					var w4: float = _take(counts, b2, 49)
					var weight: float = w1 * w2 * w3 * w4
					if weight > 0.0:
						var player: int = (p1 + p2) % 10
						var banker: int = (b1 + b2) % 10
						for s: int in sides.size():
							returns[s] += weight * _dragon_after_deal(sides[s], player, banker, counts)
					_give(counts, b2)
				_give(counts, p2)
			_give(counts, b1)
		_give(counts, p1)
	_assert_in_band(returns[0])
	_assert_in_band(returns[1])
	# The value engine (side-bet heat) agrees, with nothing seen.
	var none: Array[Card] = []
	for s: int in sides.size():
		var bet: SideBet = SideBet.on_side(SideBetKind.Kind.DRAGON_BONUS, 1, sides[s])
		var value: float = SideBetValue.dragon_bonus(
			_rules, _baccarat.natural_min, bet, none, _deck
		)
		assert_float(value).is_equal_approx(returns[s], 0.000001)


## The expected return from two-card totals, playing out the third cards.
func _dragon_after_deal(
	side: BaccaratRound.BetSide, player: int, banker: int, counts: Array[int]
) -> float:
	if player >= _baccarat.natural_min or banker >= _baccarat.natural_min:
		return _pays_back(SideBetPayout.dragon_bonus(_rules, side, player, banker, true))
	var left: int = 48
	if not BaccaratRules.player_draws(player):
		return _dragon_banker(side, player, banker, BaccaratRules.NO_THIRD, counts, left)
	var total: float = 0.0
	for third: int in VALUES:
		var weight: float = _take(counts, third, left)
		if weight > 0.0:
			total += weight * _dragon_banker(
				side, (player + third) % 10, banker, third, counts, left - 1
			)
		_give(counts, third)
	return total


func _dragon_banker(
	side: BaccaratRound.BetSide,
	player: int,
	banker: int,
	player_third: int,
	counts: Array[int],
	left: int
) -> float:
	if not BaccaratRules.banker_draws(banker, player_third):
		return _pays_back(SideBetPayout.dragon_bonus(_rules, side, player, banker, false))
	var total: float = 0.0
	for third: int in VALUES:
		var weight: float = _take(counts, third, left)
		if weight > 0.0:
			var pays: int = SideBetPayout.dragon_bonus(
				_rules, side, player, (banker + third) % 10, false
			)
			total += weight * _pays_back(pays)
		_give(counts, third)
	return total


## Takes one card of value from counts; returns its chance out of left.
## Always pair with _give(), even at weight 0.
func _take(counts: Array[int], value: int, left: int) -> float:
	var weight: float = float(counts[value]) / left
	counts[value] -= 1
	return weight


func _give(counts: Array[int], value: int) -> void:
	counts[value] += 1


func test_pair_edge() -> void:
	# Either side reads its own first two cards: the same enumeration.
	var total: float = 0.0
	var hands: int = 0
	for i: int in _deck.size():
		for j: int in range(i + 1, _deck.size()):
			total += _pays_back(SideBetPayout.pair(_rules, _deck[i], _deck[j]))
			hands += 1
	_assert_in_band(total / hands)


func test_exact_rank_edge_for_every_call() -> void:
	for called: int in range(1, RANKS + 1):
		var total: float = 0.0
		for card: Card in _deck:
			total += _pays_back(SideBetPayout.exact_rank(_rules, called, card))
		_assert_in_band(total / _deck.size())
