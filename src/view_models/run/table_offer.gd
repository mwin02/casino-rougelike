class_name TableOffer
extends RefCounted
## One table as the floor screens offer it (spec §5.2): its game, stakes
## and house rule, and whether the pit boss watches it (§7.5). Its cost
## rolls stay hidden.

const NO_RULE: String = "None"

## The table's place at its node.
var index: int
var game: GameKind.Kind
## "Blackjack".
var name: String
## "$5,000–$20,000".
var stakes_text: String
## The house rule's name, or "None".
var rule_text: String
## What the house rule does; empty with none.
var rule_note: String
var watched: bool


func _init(p_index: int, table: Table) -> void:
	index = p_index
	game = table.game
	name = TableSetupVM.GAME_NAMES[table.game]
	stakes_text = "%s–%s" % [
		MoneyFormat.format(table.table_min), MoneyFormat.format(table.table_max)
	]
	var rule: String = table.house_rule
	rule_text = NO_RULE if rule.is_empty() else HouseRuleText.name_of(rule)
	rule_note = HouseRuleText.describe(rule)
	watched = table.watched


static func of_node(node: MapNode) -> Array[TableOffer]:
	var offers: Array[TableOffer] = []
	for i: int in node.tables.size():
		offers.append(TableOffer.new(i, node.tables[i]))
	return offers
