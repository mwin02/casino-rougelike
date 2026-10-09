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
## The games it sits at; empty for any.
var games: Array[GameKind.Kind] = []
## Saves its hands for the payoff: skips low-stakes tables while the
## bankroll covers the floor's high stakes.
var skips_low: bool = false


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


## Buys deck services, keeping keep. None by default.
func use_services(_services: DeckServices, _deck: Deck, _keep: int) -> void:
	pass


## The next node: a table node with a table of its games the bankroll
## covers, in stakes_order, else whatever comes first.
func route(choices: Array[MapNode], bankroll: int, deck: Deck) -> MapNode:
	for stakes: TableStakes.Kind in stakes_order(deck):
		for node: MapNode in choices:
			if node.kind == MapNode.Kind.TABLES and node.stakes == stakes and _fits(node, bankroll):
				return node
	return choices[0]


## Whether it sits at node, given the bankroll and the floor's high-stakes
## minimum.
func sits_at(node: MapNode, bankroll: int, high_min: int) -> bool:
	return not (skips_low and node.stakes == TableStakes.Kind.LOW and bankroll >= high_min)


## High stakes first.
func stakes_order(_deck: Deck) -> Array[TableStakes.Kind]:
	return [TableStakes.Kind.HIGH, TableStakes.Kind.LOW]


## What the security sweep takes, the least valued choice: an item off the
## wishlist, then the wishlist from its tail, then a symbol's marks, then
## one of its own unlocks.
func sweep_choice(choices: Array[SweepChoice]) -> SweepChoice:
	var best: SweepChoice = choices[0]
	for choice: SweepChoice in choices:
		if _sweep_value(choice) < _sweep_value(best):
			best = choice
	return best


func _fits(node: MapNode, bankroll: int) -> bool:
	for table: Table in node.tables:
		if (games.is_empty() or table.game in games) and bankroll >= table.table_min:
			return true
	return false


func _sweep_value(choice: SweepChoice) -> int:
	if choice.kind == SweepChoice.Kind.SYMBOL:
		return wishlist.size() + 1
	if choice.item in unlocks:
		return wishlist.size() + 2
	if choice.item in wishlist:
		return wishlist.size() - wishlist.find(choice.item)
	return 0
