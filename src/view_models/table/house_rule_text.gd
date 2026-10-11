class_name HouseRuleText
extends RefCounted
## A house rule's name and one-line description for a table offer (spec
## §5.2), by its config name. A rule with no text here reads as its config
## name.

const NAMES: Dictionary[String, String] = {
	"bust_23": "Bust at 23",
	"nine_only": "Nine only",
	"aces_high": "Aces high",
	"no_side_bets": "No side bets",
}
const DESCRIPTIONS: Dictionary[String, String] = {
	"bust_23": "23 or more busts, so a 22 is live. The dealer's rules don't change.",
	"nine_only": "Only a two-card 9 is a natural. A two-card 8 no longer ends the hand.",
	"aces_high": "The ace ranks above the king.",
	"no_side_bets": "This table takes no side bets.",
}
const NO_RULE: String = "No house rule"


static func name_of(rule: String) -> String:
	if NAMES.has(rule):
		return NAMES[rule]
	var plain: String = rule.replace("_", " ")
	return plain.left(1).to_upper() + plain.substr(1)


static func describe(rule: String) -> String:
	return DESCRIPTIONS.get(rule, "")


## "House rule: Aces high. The ace ranks above the king." Empty for no rule.
static func offer_line(rule: String) -> String:
	if rule.is_empty():
		return ""
	var line: String = "House rule: " + name_of(rule)
	var description: String = describe(rule)
	return line if description.is_empty() else "%s. %s" % [line, description]
