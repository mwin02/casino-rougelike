class_name HandHeat
extends RefCounted
## One hand's heat (spec §1.1, §1.4, §1.5, §7.1). Each action is charged as
## it lands, as its own line: its base cost at this table, ×1.7 in any window
## after the first one acted in, × the tier the hand started in. resolve()
## adds a line per adjust and side switch (the bet-change base × the tier;
## doubles, splits and insurance add none), then the multiplier as a last
## line, on everything before it.

const BET_CHANGES_WITH_BASE: Array[BetChange.Kind] = [
	BetChange.Kind.ADJUST, BetChange.Kind.SIDE_SWITCH
]

var lines: Array[HeatLine] = []
## The table's tier when the hand started. It prices the whole hand.
var tier: HeatTier.Kind
## Hook for Deep Read (§9): no second window surcharge.
var deep_read: bool = false

var _rules: HeatRules
var _costs: TableCosts
var _session: ActionSession
var _first_window: int = 0
var _resolved: bool = false


func _init(
	rules: HeatRules, costs: TableCosts, p_tier: HeatTier.Kind, session: ActionSession
) -> void:
	_rules = rules
	_costs = costs
	tier = p_tier
	_session = session


## What the action would cost if taken now, in this window.
func cost_of(action: ActionKind.Kind, window_number: int) -> float:
	return _line(action, window_number).amount


## Charges an action just taken. Mark is priced by the marks made before it.
func charge(use: ActionUse) -> HeatLine:
	var line: HeatLine = _line(use.action, use.window_number)
	if _first_window == 0:
		_first_window = use.window_number
	lines.append(line)
	return line


## Adds a line per adjust and side switch, then the multiplier line: m(r)
## on all the hand's heat, where r compares the total bet now with the
## opening bet. Any side switch counts as the largest ratio (§3.2). Once per
## hand; returns the multiplier line.
func resolve(rnd: GameRound) -> HeatLine:
	if _resolved:
		return null
	_resolved = true
	for change: BetChange in rnd.bet_changes:
		if change.kind in BET_CHANGES_WITH_BASE:
			lines.append(
				HeatLine.for_bet_change(
					change.kind, _rules.bet_change_base, _rules.cost_multiplier(tier)
				)
			)
	var r: float = ratio(rnd)
	var line: HeatLine = HeatLine.for_multiplier(r, _rules.multiplier(r), total())
	lines.append(line)
	return line


## Every line's heat so far.
func total() -> float:
	var sum: float = 0.0
	for line: HeatLine in lines:
		sum += line.amount
	return sum


func ratio(rnd: GameRound) -> float:
	for change: BetChange in rnd.bet_changes:
		if change.kind == BetChange.Kind.SIDE_SWITCH:
			return _rules.max_ratio
	var final_bet: float = rnd.total_bet()
	var opening: float = rnd.opening_bet
	return maxf(final_bet / opening, opening / final_bet)


func _line(action: ActionKind.Kind, window_number: int) -> HeatLine:
	var later: bool = _first_window != 0 and window_number != _first_window
	var surcharge: float = _rules.second_window_surcharge if later and not deep_read else 1.0
	return HeatLine.for_action(
		action,
		_costs.base_cost(action, _session.marks_made),
		surcharge,
		_rules.cost_multiplier(tier)
	)
