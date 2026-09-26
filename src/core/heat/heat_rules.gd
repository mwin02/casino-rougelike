class_name HeatRules
extends RefCounted
## Heat [TUNE] values (spec §1, §2.3, §3.3, §7.1, §7.2): the bet-change
## multiplier, the second window surcharge, the per-table roll ranges, the
## tiers, cooling, the Marked consequence's odds, and each action's center
## cost per game.

## m(r) passes through these points, linear between them (§1.1).
var multiplier_ratios: Array[float] = []
var multiplier_values: Array[float] = []
## The r a side switch counts as: the largest change the bet limits allow
## (§1.3, §3.2), up or down.
var max_ratio: float
## §1.5
var second_window_surcharge: float
## §2.3: each mark this session adds this to the next mark's base.
var mark_step: float
## Where Watched, Marked and Backed off start (§7.1).
var tier_thresholds: Array[float] = []
## Action cost multipliers in Clean, Watched and Marked.
var tier_cost_multipliers: Array[float] = []
## §1.6
var cool_rate: float
## stake_factor passes through these points: the bet's position between the
## table min (0) and max (1), and its factor.
var stake_factor_positions: Array[float] = []
var stake_factor_values: Array[float] = []
## §7.2: P(house deck swap) on floors 1–5.
var house_swap_chance: Array[float] = []

## §2.3 blackjack reference costs.
var _centers: Dictionary[ActionKind.Kind, float] = {}
## §3.3: High or Low's factors on the blackjack base.
var _high_low_reveal_factor: float
var _high_low_manipulation_factor: float
## [stakes][is manipulation] -> [min, max] share of the center.
var _ranges: Dictionary[TableStakes.Kind, Array] = {}


static func from_config(config: TuneConfig) -> HeatRules:
	var rules: HeatRules = HeatRules.new()
	rules.multiplier_ratios = config.get_float_list("heat", "multiplier_ratios")
	rules.multiplier_values = config.get_float_list("heat", "multiplier_values")
	rules.max_ratio = maxf(
		config.get_int("heat", "max_raise_pct") / 100.0,
		100.0 / config.get_int("heat", "min_decrease_pct")
	)
	rules.second_window_surcharge = config.get_float("heat", "second_window_surcharge")
	rules.mark_step = config.get_float("actions", "mark_step")
	rules.tier_thresholds = config.get_float_list("tiers", "thresholds")
	rules.tier_cost_multipliers = config.get_float_list("tiers", "cost_multipliers")
	rules.cool_rate = config.get_float("cooling", "cool_rate")
	rules.stake_factor_positions = config.get_float_list("cooling", "stake_factor_positions")
	rules.stake_factor_values = config.get_float_list("cooling", "stake_factor_values")
	rules.house_swap_chance = config.get_float_list("consequences", "house_swap_chance")
	for action: ActionKind.Kind in ActionKind.Kind.values():
		var key: String = ActionKind.Kind.keys()[action]
		rules._centers[action] = config.get_float("actions", key.to_lower())
	rules._high_low_reveal_factor = config.get_float("high_low", "reveal_cost_factor")
	rules._high_low_manipulation_factor = config.get_float("high_low", "manipulation_cost_factor")
	rules._ranges[TableStakes.Kind.LOW] = [
		_range(config, "low_stakes_information"), _range(config, "low_stakes_manipulation")
	]
	rules._ranges[TableStakes.Kind.HIGH] = [
		_range(config, "high_stakes_information"), _range(config, "high_stakes_manipulation")
	]
	return rules


## m(r): 1 at r = 1, linear between the points, holding past the last one.
func multiplier(r: float) -> float:
	return _through(multiplier_ratios, multiplier_values, r)


## §1.6: the cooling factor for a bet at position (0 at table min, 1 at max).
func stake_factor(position: float) -> float:
	return _through(stake_factor_positions, stake_factor_values, position)


## Where the Marked tier starts, and the consequence fires (§7.2).
func marked_from() -> float:
	return tier_thresholds[HeatTier.Kind.MARKED - 1]


func tier_of(heat: float) -> HeatTier.Kind:
	var tier: int = HeatTier.Kind.CLEAN
	for threshold: float in tier_thresholds:
		if heat >= threshold:
			tier += 1
	return tier as HeatTier.Kind


## A backed-off table deals no more hands (§7.1), so Backed off only
## clamps to Marked to stay defined.
func cost_multiplier(tier: HeatTier.Kind) -> float:
	return tier_cost_multipliers[mini(tier, tier_cost_multipliers.size() - 1)]


## The action's center base cost at this game, before any table roll.
func center(game: GameKind.Kind, action: ActionKind.Kind) -> float:
	var cost: float = _centers[action]
	if game != GameKind.Kind.HIGH_LOW or action == ActionKind.Kind.MARK:
		return cost
	if action in ActionKind.MANIPULATION:
		return cost * _high_low_manipulation_factor
	return cost * _high_low_reveal_factor


## [min, max] share of the center a table of these stakes rolls within, for
## manipulation or for information (marks included).
func roll_range(stakes: TableStakes.Kind, manipulation: bool) -> Vector2:
	var ranges: Array = _ranges[stakes]
	return ranges[1] if manipulation else ranges[0]


## y at x on the line through the points, holding flat past either end.
static func _through(xs: Array[float], ys: Array[float], x: float) -> float:
	if x <= xs[0]:
		return ys[0]
	for i: int in range(1, xs.size()):
		if x <= xs[i]:
			return lerpf(ys[i - 1], ys[i], inverse_lerp(xs[i - 1], xs[i], x))
	return ys[-1]


static func _range(config: TuneConfig, key: String) -> Vector2:
	var pair: Array[float] = config.get_float_list("table_rolls", key)
	return Vector2(pair[0], pair[1])
