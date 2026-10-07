class_name ItemText
extends RefCounted
## Item text (spec §9): what items added to a hand, and what the Pit Ledger
## shows of a table.

const CONSEQUENCE_NAMES: Dictionary[MarkedConsequence.Kind, String] = {
	MarkedConsequence.Kind.HOUSE_DECK_SWAP: "house deck swap",
	MarkedConsequence.Kind.NEW_DEALER: "new dealer",
}


## "Signature +$250", one line per bonus.
static func bonus_lines(bonuses: Array[ItemBonus]) -> PackedStringArray:
	var lines: PackedStringArray = []
	for bonus: ItemBonus in bonuses:
		lines.append(
			"%s %s" % [ItemKind.NAMES[bonus.item], MoneyFormat.format_signed(bonus.dollars)]
		)
	return lines


## Every action's rolled base cost, then the Marked consequence.
static func ledger_text(ledger: PitLedger) -> String:
	var costs: PackedStringArray = []
	for action: ActionKind.Kind in ActionKind.Kind.values():
		costs.append(
			HeatText.action_name(action) + " " + HeatText.number(ledger.costs.base_cost(action, 0))
		)
	return "Pit Ledger: %s; if Marked, %s" % [
		", ".join(costs), CONSEQUENCE_NAMES[ledger.consequence]
	]
