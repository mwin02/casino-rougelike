class_name SweepChoice
extends RefCounted
## What the player gives up to a security sweep (spec §7.6): one owned item,
## or every mark of one symbol.

enum Kind { ITEM, SYMBOL }

var kind: Kind
## The item lost, for an ITEM choice.
var item: ItemKind.Kind
## The symbol whose marks are cleared, for a SYMBOL choice.
var symbol: int = Card.NO_SYMBOL


static func of_item(p_item: ItemKind.Kind) -> SweepChoice:
	var choice: SweepChoice = SweepChoice.new()
	choice.kind = Kind.ITEM
	choice.item = p_item
	return choice


static func of_symbol(p_symbol: int) -> SweepChoice:
	var choice: SweepChoice = SweepChoice.new()
	choice.kind = Kind.SYMBOL
	choice.symbol = p_symbol
	return choice


func same_as(other: SweepChoice) -> bool:
	if kind != other.kind:
		return false
	return item == other.item if kind == Kind.ITEM else symbol == other.symbol
