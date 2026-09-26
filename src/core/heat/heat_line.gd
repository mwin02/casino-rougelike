class_name HeatLine
extends RefCounted
## One itemized line of heat (spec §1.4): an action's heat when it lands, or
## the bet-change multiplier's effect at resolution.

enum Kind { ACTION, MULTIPLIER }

var kind: Kind
## Heat added.
var amount: float
## ACTION lines: the action, its base cost here, and what multiplied it.
var action: ActionKind.Kind
var base: float
## 1, or the second window surcharge (§1.5).
var surcharge: float = 1.0
## The tier's cost multiplier (§7.1).
var tier_multiplier: float = 1.0
## MULTIPLIER lines: r and m(r) (§1.1).
var ratio: float = 1.0
var multiplier: float = 1.0


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


## subtotal is the hand's action heat; the line adds subtotal × (m(r) − 1).
static func for_multiplier(p_ratio: float, p_multiplier: float, subtotal: float) -> HeatLine:
	var line: HeatLine = HeatLine.new()
	line.kind = Kind.MULTIPLIER
	line.ratio = p_ratio
	line.multiplier = p_multiplier
	line.amount = subtotal * (p_multiplier - 1.0)
	return line
