class_name HeatLine
extends RefCounted
## One itemized line of heat (spec §1.4): an action's heat when it lands and
## its side-bet heat (§8) with it, a bet change's base and the multiplier's
## effect at resolution, or what the table did after the hand: cooling, a
## tier change, the Marked consequence, backing the player off.

enum Kind { ACTION, BET_CHANGE, MULTIPLIER, COOLING, TIER, CONSEQUENCE, BACKED_OFF, SIDE_BET }

var kind: Kind
## Heat added (negative for cooling). 0 for TIER, CONSEQUENCE, BACKED_OFF.
var amount: float
## ACTION lines: the action, its base cost here, and what multiplied it.
var action: ActionKind.Kind
var base: float
## BET_CHANGE lines: the change (an adjust or a side switch).
var bet_change: BetChange.Kind
## 1, or the second window surcharge (§1.5).
var surcharge: float = 1.0
## The tier's cost multiplier (§7.1).
var tier_multiplier: float = 1.0
## MULTIPLIER lines: r and m(r) (§1.1).
var ratio: float = 1.0
var multiplier: float = 1.0
## TIER lines: the tier the table moved into.
var tier: HeatTier.Kind
## CONSEQUENCE lines: what happened (§7.2).
var consequence: MarkedConsequence.Kind


static func for_action(
	p_action: ActionKind.Kind, p_base: float, p_surcharge: float, p_tier_multiplier: float
) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = Kind.ACTION
	line.action = p_action
	line.base = p_base
	line.surcharge = p_surcharge
	line.tier_multiplier = p_tier_multiplier
	line.amount = p_base * p_surcharge * p_tier_multiplier
	return line


## §1.1: one adjust or side switch, its base × the tier.
static func for_bet_change(
	p_bet_change: BetChange.Kind, p_base: float, p_tier_multiplier: float
) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = Kind.BET_CHANGE
	line.bet_change = p_bet_change
	line.base = p_base
	line.tier_multiplier = p_tier_multiplier
	line.amount = p_base * p_tier_multiplier
	return line


## subtotal is the hand's action heat; the line adds subtotal × (m(r) − 1).
static func for_multiplier(p_ratio: float, p_multiplier: float, subtotal: float) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = Kind.MULTIPLIER
	line.ratio = p_ratio
	line.multiplier = p_multiplier
	line.amount = subtotal * (p_multiplier - 1.0)
	return line


## §8: a manipulation's side-bet heat, its base × the tier.
static func for_side_bet(p_base: float, p_tier_multiplier: float) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = Kind.SIDE_BET
	line.base = p_base
	line.tier_multiplier = p_tier_multiplier
	line.amount = p_base * p_tier_multiplier
	return line


static func for_table(p_kind: Kind, p_amount: float = 0.0) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = p_kind
	line.amount = p_amount
	return line
