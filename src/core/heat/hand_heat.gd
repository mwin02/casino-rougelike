class_name HandHeat
extends RefCounted
## One hand's heat (spec §1.1, §1.4, §1.5, §7.1). Each action is charged as
## it lands, as its own line: its base cost at this table, ×1.7 in any window
## after the first one acted in, × the tier the hand started in. A
## manipulation that raises the side bets' value adds a side-bet line with it
## (§8). resolve() adds a line per adjust and side switch (the game's
## bet-change base × the tier; doubles, splits and insurance add none), then
## the multiplier as a last line, on everything before it but side-bet heat.
## Items in the kit change some of these costs (§9).

const BET_CHANGES_WITH_BASE: Array[BetChange.Kind] = [
	BetChange.Kind.ADJUST, BetChange.Kind.SIDE_SWITCH
]

var lines: Array[HeatLine] = []
## The table's tier when the hand started. It prices the whole hand.
var tier: HeatTier.Kind

var _rules: HeatRules
var _costs: TableCosts
var _session: ActionSession
## The items that change action costs (§9).
var _kit: ActionKit
var _first_window: int = 0
var _resolved: bool = false


func _init(
	rules: HeatRules,
	costs: TableCosts,
	p_tier: HeatTier.Kind,
	session: ActionSession,
	kit: ActionKit = null
) -> void:
	_rules = rules
	_costs = costs
	tier = p_tier
	_session = session
	_kit = kit if kit != null else ActionKit.starting()


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


## §8: the heat for raising the side bets' value by gain dollars at a table
## with this max. No later-window surcharge; × the tier. 0 for no gain.
func side_bet_cost(gain: float, table_max: int, action: ActionKind.Kind, earlier: int) -> float:
	return _side_bet_line(gain, table_max, action, earlier).amount if gain > 0.0 else 0.0


## Charges side-bet heat with the manipulation that made the gain.
func charge_side_bets(
	gain: float, table_max: int, action: ActionKind.Kind, earlier: int
) -> void:
	if gain > 0.0:
		lines.append(_side_bet_line(gain, table_max, action, earlier))


## Adds a line per adjust and side switch, then the multiplier line: m(r)
## on all the hand's heat, where r compares the total bet now with the
## opening bet. Any side switch counts as the largest ratio (§3.2). Once per
## hand; returns the multiplier line.
func resolve(rnd: GameRound) -> HeatLine:
	if _resolved:
		return null
	_resolved = true
	for change: BetChange in rnd.bet_changes:
		if change.kind in BET_CHANGES_WITH_BASE and _pays_base(change):
			lines.append(
				HeatLine.for_bet_change(
					change.kind,
					_rules.bet_change_base(_costs.game),
					_rules.cost_multiplier(tier)
				)
			)
	var r: float = ratio(rnd)
	var multiplied: float = 0.0
	for heat_line: HeatLine in lines:
		if heat_line.kind != HeatLine.Kind.SIDE_BET:
			multiplied += heat_line.amount
	var line: HeatLine = HeatLine.for_multiplier(r, _rules.multiplier(r), multiplied)
	lines.append(line)
	return line


## Every line's heat so far.
func total() -> float:
	var sum: float = 0.0
	for line: HeatLine in lines:
		sum += line.amount
	return sum


## Quiet Hands (§9): a lowered bet counts as unchanged.
func ratio(rnd: GameRound) -> float:
	for change: BetChange in rnd.bet_changes:
		if change.kind == BetChange.Kind.SIDE_SWITCH:
			return _rules.max_ratio
	var final_bet: float = rnd.total_bet()
	var opening: float = rnd.opening_bet
	if _kit.quiet_hands and final_bet < opening:
		return 1.0
	return maxf(final_bet / opening, opening / final_bet)


## §1.1 [OPEN]: with Quiet Hands, whether a decrease pays the base is a hook.
func _pays_base(change: BetChange) -> bool:
	return change.amount >= 0 or not _kit.quiet_hands or _kit.quiet_hands_decrease_pays_base


func _side_bet_line(
	gain: float, table_max: int, action: ActionKind.Kind, earlier: int
) -> HeatLine:
	var base: float = gain / table_max * _rules.side_bet_rate(action, earlier)
	return HeatLine.for_side_bet(base, _rules.cost_multiplier(tier))


func _line(action: ActionKind.Kind, window_number: int) -> HeatLine:
	var later: bool = _first_window != 0 and window_number != _first_window
	var surcharge: float = _rules.second_window_surcharge if later and not _kit.deep_read else 1.0
	return HeatLine.for_action(
		action, 0.0 if _kit.poker_face and not later else _base(action), surcharge,
		_rules.cost_multiplier(tier)
	)


## The table's base cost after items (§9): Sleight cuts the Nudge, Tell
## Reader cuts marks at low stakes.
func _base(action: ActionKind.Kind) -> float:
	var base: float = _costs.base_cost(action, _session.marks_made)
	if action == ActionKind.Kind.NUDGE:
		return base * _kit.nudge_cost_pct / 100.0
	if action == ActionKind.Kind.MARK and _costs.stakes == TableStakes.Kind.LOW:
		return maxf(base - _kit.low_stakes_mark_cut, 0.0)
	return base
