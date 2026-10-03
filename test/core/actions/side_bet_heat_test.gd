extends GdUnitTestSuite
## Side-bet heat (spec §8): a manipulation that raises the side bets' value,
## as the player can see it, costs heat for the gain, × its action's factor
## and × a repeat multiplier for manipulations earlier in the hand. The
## player sees that cost before acting. It lands with the action, × the
## tier, never at resolution, with no later-window surcharge and outside m(r).

const STAKE: int = 1000

var _f: ActionsFixture
var _rules: SideBetRules
var _side_bet_heat: float


func before_test() -> void:
	_f = ActionsFixture.new()
	_rules = SideBetRules.from_config(_f.config)
	_side_bet_heat = _f.config.get_float("side_bets", "side_bet_heat")
	_f.side_bets = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE)]


## Player 7H 8D; a palm of the 8D into 7D makes a coloured pair.
func _pairs_hand() -> HandActions:
	return _f.actions(_f.blackjack(["7H", "5S", "8D", "9C", "K", "K", "K"]))


func _pair_gain() -> float:
	return float(STAKE * _rules.perfect_pairs[1] + STAKE)


## Side-bet heat for gain made by action, after earlier manipulations.
func _heat_for(gain: float, action: String = "palm", earlier: int = 0) -> float:
	var factor: float = _f.config.get_float("side_bets", action + "_heat_factor")
	var repeats: Array[float] = _f.config.get_float_list("side_bets", "repeat_heat_multipliers")
	var repeat: float = repeats[mini(earlier, repeats.size() - 1)]
	return gain / ActionsFixture.TABLE_MAX * _side_bet_heat * factor * repeat


func _side_lines(hand: HandActions) -> Array[HeatLine]:
	var result: Array[HeatLine] = []
	for line: HeatLine in hand.heat.lines:
		if line.kind == HeatLine.Kind.SIDE_BET:
			result.append(line)
	return result


func test_a_manipulation_that_wins_a_side_bet_costs_its_gain() -> void:
	var hand: HandActions = _pairs_hand()
	assert_bool(hand.palm(2, 7, Card.Suit.DIAMONDS)).is_true()
	var lines: Array[HeatLine] = _side_lines(hand)
	assert_int(lines.size()).is_equal(1)
	assert_float(lines[0].amount).is_equal_approx(_heat_for(_pair_gain()), 0.0001)


func test_the_cost_shows_before_the_action() -> void:
	var hand: HandActions = _pairs_hand()
	var preview: float = hand.palm_cost(2, 7, Card.Suit.DIAMONDS)
	assert_float(preview).is_greater(hand.cost_of(ActionKind.Kind.PALM))
	var before: float = hand.heat.total()
	hand.palm(2, 7, Card.Suit.DIAMONDS)
	assert_float(hand.heat.total() - before).is_equal_approx(preview, 0.0001)


func test_every_manipulation_previews_its_side_bet_heat() -> void:
	var hand: HandActions = _pairs_hand()
	var plain: float = hand.cost_of(ActionKind.Kind.NUDGE)
	# 8D down to 7D pairs the 7H; 8D up doesn't.
	assert_float(hand.nudge_cost(2, -1)).is_greater(plain)
	assert_float(hand.nudge_cost(2, 1)).is_equal(plain)
	assert_float(hand.recolour_cost(2, Card.Suit.HEARTS)).is_equal(
		hand.cost_of(ActionKind.Kind.RECOLOUR)
	)
	# The 7H and the 8D trade places: still no pair.
	assert_float(hand.switch_cost(0, 2)).is_equal(hand.cost_of(ActionKind.Kind.SWITCH))


func test_a_manipulation_that_doesnt_help_adds_nothing() -> void:
	var hand: HandActions = _pairs_hand()
	hand.nudge(1, 1)
	assert_array(_side_lines(hand)).is_empty()


func test_the_tier_scales_side_bet_heat() -> void:
	_f.tier = HeatTier.Kind.WATCHED
	var hand: HandActions = _pairs_hand()
	hand.palm(2, 7, Card.Suit.DIAMONDS)
	var tier: float = HeatRules.from_config(_f.config).cost_multiplier(HeatTier.Kind.WATCHED)
	assert_float(_side_lines(hand)[0].amount).is_equal_approx(
		_heat_for(_pair_gain()) * tier, 0.0001
	)


func test_side_bet_heat_takes_no_later_window_surcharge() -> void:
	var hand: HandActions = _pairs_hand()
	hand.full_reveal(3)
	var rnd: BlackjackRound = _f.last_round as BlackjackRound
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	hand.palm(2, 7, Card.Suit.DIAMONDS)
	assert_float(_side_lines(hand)[0].amount).is_equal_approx(_heat_for(_pair_gain()), 0.0001)


func test_side_bet_heat_never_lands_at_resolution() -> void:
	var hand: HandActions = _pairs_hand()
	var rnd: BlackjackRound = _f.last_round as BlackjackRound
	rnd.proceed()
	rnd.adjust(2000)
	rnd.proceed()
	rnd.hit()
	hand.palm(2, 7, Card.Suit.DIAMONDS)
	var landed: int = hand.heat.lines.size()
	var action_heat: float = hand.heat.lines[0].amount
	var multiplier: HeatLine = hand.heat.resolve(rnd)
	assert_int(_side_lines(hand).size()).is_equal(1)
	assert_int(hand.heat.lines.size()).is_equal(landed + 2)  # the adjust and m(r)
	# m(r) multiplies the action and the adjust, not the side-bet line.
	var adjust_heat: float = hand.heat.lines[landed].amount
	var m: float = multiplier.multiplier
	assert_float(multiplier.amount).is_equal_approx((action_heat + adjust_heat) * (m - 1.0), 0.0001)


func test_a_blind_change_shows_nothing_and_costs_nothing() -> void:
	# Pair on the banker; the banker's second card is face down. Nudging it
	# blind can't be priced from what the player sees, so a preview never
	# gives its face away.
	_f.side_bets = [SideBet.on_side(SideBetKind.Kind.PAIR, STAKE, BaccaratRound.BetSide.BANKER)]
	var costs: Array[float] = []
	for hidden: String in ["3", "5"]:
		var hand: HandActions = _f.actions(_f.baccarat(["K", "4", "10", hidden, "2", "6"]))
		costs.append(hand.nudge_cost(3, 1))
		costs.append(hand.nudge_cost(3, -1))
		hand.nudge(3, 1)
		assert_array(_side_lines(hand)).is_empty()
	assert_float(costs[0]).is_equal(costs[2])
	assert_float(costs[1]).is_equal(costs[3])


func test_a_blind_palm_prices_the_card_it_leaves() -> void:
	# Palming the banker's hidden card into a 3 (banker 7, player 0 draws)
	# leaves the player's third card to the unseen cards. The card palmed
	# away is one of them as far as the player knows, so the cost is the same
	# whatever it was.
	var dragon: SideBet = SideBet.on_side(
		SideBetKind.Kind.DRAGON_BONUS, STAKE, BaccaratRound.BetSide.BANKER
	)
	_f.side_bets = [dragon]
	var costs: Array[float] = []
	var piles: Array[Array] = [
		["K", "4", "10", "3", "2", "6"],
		["K", "4", "10", "6", "2", "3"],
	]
	for codes: Array in piles:
		var pile: Array[String] = []
		pile.assign(codes)
		var hand: HandActions = _f.actions(_f.baccarat(pile))
		costs.append(hand.palm_cost(3, 3, Card.Suit.HEARTS))
		assert_float(costs.back()).is_greater(hand.cost_of(ActionKind.Kind.PALM))
	assert_float(costs[0]).is_equal_approx(costs[1], 0.0001)


func test_a_switch_preview_never_shows_the_hidden_card() -> void:
	# Player 7H 8D. Switching the 8D with the hole card would pair the 7H if
	# the hole is the 7D; the cost can't say whether it is.
	var costs: Array[float] = []
	for hole: String in ["7D", "2C"]:
		var other: String = "2C" if hole == "7D" else "7D"
		var hand: HandActions = _f.actions(_f.blackjack(["7H", "5S", "8D", hole, other]))
		costs.append(hand.switch_cost(3, 2))
	assert_float(costs[0]).is_equal_approx(costs[1], 0.0001)


func test_a_single_nudge_costs_its_action_factor() -> void:
	var hand: HandActions = _pairs_hand()
	hand.nudge(2, -1)
	var lines: Array[HeatLine] = _side_lines(hand)
	assert_float(lines[0].amount).is_equal_approx(_heat_for(_pair_gain(), "nudge"), 0.0001)
	assert_float(lines[0].amount).is_less(_heat_for(_pair_gain(), "palm"))


func test_each_manipulation_earlier_in_the_hand_raises_side_bet_heat() -> void:
	# 9D down twice to 7D: the first Nudge gains nothing, the second makes
	# the pair after one earlier manipulation.
	var hand: HandActions = _f.actions(_f.blackjack(["7H", "5S", "9D", "9C", "K", "K", "K"]))
	hand.nudge(2, -1)
	assert_array(_side_lines(hand)).is_empty()
	var preview: float = hand.nudge_cost(2, -1)
	var before: float = hand.heat.total()
	hand.nudge(2, -1)
	var side: float = _side_lines(hand)[0].amount
	assert_float(side).is_equal_approx(_heat_for(_pair_gain(), "nudge", 1), 0.0001)
	assert_float(side).is_greater(_heat_for(_pair_gain(), "nudge", 0))
	assert_float(hand.heat.total() - before).is_equal_approx(preview, 0.0001)
