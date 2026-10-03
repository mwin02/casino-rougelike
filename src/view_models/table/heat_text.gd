class_name HeatText
extends RefCounted
## Heat as the table screen words it (spec §1.4): one line per action as it
## lands, the multiplier's effect, cooling, and what the table did, plus the
## hand's efficiency line. Heat shows to one decimal, with a whole number
## written bare.
##
## The table's rolled costs and the multiplier's workings are hidden in the
## game (§1.1, §1.4); reveal_costs shows them. The debug table turns it on;
## the real screen and the Pit Ledger (§9) decide later.

const ACTION_NAMES: Dictionary[ActionKind.Kind, String] = {
	ActionKind.Kind.PARTIAL_REVEAL: "Partial reveal",
	ActionKind.Kind.MARK: "Mark",
	ActionKind.Kind.FULL_REVEAL: "Full reveal",
	ActionKind.Kind.LOOK_AHEAD: "Look ahead",
	ActionKind.Kind.RECOLOUR: "Recolour",
	ActionKind.Kind.NUDGE: "Nudge",
	ActionKind.Kind.SWITCH: "Switch",
	ActionKind.Kind.PALM: "Palm",
}
const BET_CHANGE_NAMES: Dictionary[BetChange.Kind, String] = {
	BetChange.Kind.ADJUST: "Adjust",
	BetChange.Kind.SIDE_SWITCH: "Side switch",
}
const TIER_NAMES: Dictionary[HeatTier.Kind, String] = {
	HeatTier.Kind.CLEAN: "Clean",
	HeatTier.Kind.WATCHED: "Watched",
	HeatTier.Kind.MARKED: "Marked",
	HeatTier.Kind.BACKED_OFF: "Backed off",
}
const CONSEQUENCE_TEXT: Dictionary[MarkedConsequence.Kind, String] = {
	MarkedConsequence.Kind.HOUSE_DECK_SWAP: "The pit swaps in a house deck.",
	MarkedConsequence.Kind.NEW_DEALER: "A new dealer takes the table.",
}
## Heat shows to this step.
const STEP: float = 0.1


## Signed heat: "+12", "+20.4", "-6", "0".
static func amount(heat: float) -> String:
	var shown: String = number(heat)
	return "+" + shown if snappedf(heat, STEP) > 0.0 else shown


## Heat without a plus sign: "12", "20.4".
static func number(heat: float) -> String:
	var snapped: float = snappedf(heat, STEP)
	if snapped == 0.0:
		return "0"
	var text: String = "%.1f" % snapped
	return text.trim_suffix(".0")


## One heat line. Empty for a multiplier or cooling line that moves no heat.
static func line_text(line: HeatLine, reveal_costs: bool) -> String:
	match line.kind:
		HeatLine.Kind.ACTION:
			return _action_text(line, reveal_costs)
		HeatLine.Kind.SIDE_BET:
			var side: String = "Side bets " + amount(line.amount)
			if reveal_costs and line.tier_multiplier != 1.0:
				side += " (%s × %s tier)" % [number(line.base), number(line.tier_multiplier)]
			return side
		HeatLine.Kind.BET_CHANGE:
			var change: String = BET_CHANGE_NAMES[line.bet_change] + " " + amount(line.amount)
			if reveal_costs and line.tier_multiplier != 1.0:
				change += " (%s × %s tier)" % [number(line.base), number(line.tier_multiplier)]
			return change
		HeatLine.Kind.MULTIPLIER:
			if snappedf(line.amount, STEP) == 0.0:
				return ""
			var text: String = "Bet size " + amount(line.amount)
			if reveal_costs:
				text += " (r %.1f, ×%s)" % [line.ratio, number(line.multiplier)]
			return text
		HeatLine.Kind.COOLING:
			if snappedf(line.amount, STEP) == 0.0:
				return ""
			return "Straight hand " + amount(line.amount)
		HeatLine.Kind.TIER:
			return "Table is now " + tier_name(line.tier)
		HeatLine.Kind.CONSEQUENCE:
			return CONSEQUENCE_TEXT[line.consequence]
		HeatLine.Kind.BACKED_OFF:
			return "You're backed off"
	return ""


## Every line with something to show, in order.
static func lines_text(lines: Array[HeatLine], reveal_costs: bool) -> PackedStringArray:
	var texts: PackedStringArray = []
	for line: HeatLine in lines:
		var text: String = line_text(line, reveal_costs)
		if not text.is_empty():
			texts.append(text)
	return texts


## §1.4: "+$24,000 for 6 heat ($4,000 per heat)", or "-$1,000, no heat".
static func summary_text(summary: HandSummary) -> String:
	var net: String = MoneyFormat.format_signed(summary.net)
	if not summary.has_rate():
		return net + ", no heat"
	var rate: String = MoneyFormat.format_signed(int(summary.dollars_per_heat()))
	return "%s for %s heat (%s per heat)" % [net, number(summary.heat), rate.trim_prefix("+")]


static func tier_name(tier: HeatTier.Kind) -> String:
	return TIER_NAMES[tier]


static func action_name(action: ActionKind.Kind) -> String:
	return ACTION_NAMES[action]


## What action would cost if taken now, or empty when costs are hidden.
static func cost_preview(hand: HandActions, action: ActionKind.Kind, reveal_costs: bool) -> String:
	return number(hand.cost_of(action)) if reveal_costs else ""


## "Nudge +20.4", revealed as "Nudge +20.4 (12 × 1.7 later window)".
static func _action_text(line: HeatLine, reveal_costs: bool) -> String:
	var text: String = action_name(line.action) + " " + amount(line.amount)
	if not reveal_costs or (line.surcharge == 1.0 and line.tier_multiplier == 1.0):
		return text
	var parts: PackedStringArray = [number(line.base)]
	if line.surcharge != 1.0:
		parts.append("× %s later window" % number(line.surcharge))
	if line.tier_multiplier != 1.0:
		parts.append("× %s tier" % number(line.tier_multiplier))
	return text + " (" + " ".join(parts) + ")"
