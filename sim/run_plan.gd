class_name RunPlan
extends RefCounted
## How a bot plays a run off the tables (spec §2.4, §6.4, §6.5, §7.6, §9):
## the unlocks it starts with, the items it buys, the bankroll it presses
## on to, its route, its deck services, and what it gives a sweep.

## A passed floor's surplus is what the next floor starts from (§6.3,
## §6.4), so a bot presses on to this percent of the quota before it cashes
## out.
const CASH_OUT_PCT: int = 150

var cash_out_pct: int = CASH_OUT_PCT
## The unlock items its actions need. It starts a run with them on top of
## the starting kit, in its slots.
var unlocks: Array[ItemKind.Kind] = []
## The items it buys at shops, most wanted first.
var wishlist: Array[ItemKind.Kind] = []


static func of(
	actions: Array[ActionKind.Kind],
	p_wishlist: Array[ItemKind.Kind] = [],
	p_cash_out_pct: int = CASH_OUT_PCT
) -> RunPlan:
	var plan: RunPlan = RunPlan.new()
	for item: ItemKind.Kind in ItemKind.UNLOCKS:
		if ItemKind.UNLOCKS[item] in actions:
			plan.unlocks.append(item)
	plan.wishlist = p_wishlist
	plan.cash_out_pct = p_cash_out_pct
	return plan


## Buys deck services. None by default.
func use_services(_services: DeckServices, _deck: Deck) -> void:
	pass


## The next node: a table node the bankroll covers, high stakes first, else
## whatever comes first.
func route(choices: Array[MapNode], bankroll: int) -> MapNode:
	for stakes: TableStakes.Kind in [TableStakes.Kind.HIGH, TableStakes.Kind.LOW]:
		for node: MapNode in choices:
			if (
				node.kind == MapNode.Kind.TABLES
				and node.stakes == stakes
				and bankroll >= node.tables[0].table_min
			):
				return node
	return choices[0]


## What the security sweep takes, the least valued choice: an item off the
## wishlist, then the wishlist from its tail, then a symbol's marks, then
## one of its own unlocks.
func sweep_choice(choices: Array[SweepChoice]) -> SweepChoice:
	var best: SweepChoice = choices[0]
	for choice: SweepChoice in choices:
		if _sweep_value(choice) < _sweep_value(best):
			best = choice
	return best


func _sweep_value(choice: SweepChoice) -> int:
	if choice.kind == SweepChoice.Kind.SYMBOL:
		return wishlist.size() + 1
	if choice.item in unlocks:
		return wishlist.size() + 2
	if choice.item in wishlist:
		return wishlist.size() - wishlist.find(choice.item)
	return 0
