class_name ActionKit
extends RefCounted
## What the player carries for the whole run: unlocked actions, mark symbols
## and consumables (spec §2.4, §9). Items that grant these arrive in block 13.

## §2.4: the starting kit marks with this many symbols.
const STARTING_SYMBOLS: int = 2

var unlocked: Array[ActionKind.Kind] = []
## Symbols are numbered 0 to symbols - 1.
var symbols: int = 0
## Hook for Loaded Question (§9): questions one partial reveal may ask.
var questions_per_reveal: int = 1
var masking_tape: int = 0
var cold_seals: int = 0
## Permanent Ink charges left this floor.
var ink_charges: int = 0
## Hook for Luminous Ink (§9): its symbols' marks add less to the heat floor.
var luminous_symbols: Array[int] = []
## Hook for Forged Papers (§9): the heat floor is cut.
var forged_papers: bool = false


## §2.4: partial reveal, Nudge, and Mark with two symbols.
static func starting() -> ActionKit:
	var kit: ActionKit = ActionKit.new()
	kit.unlocked = [ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.NUDGE, ActionKind.Kind.MARK]
	kit.symbols = STARTING_SYMBOLS
	return kit


## Every action unlocked, for tests and the simulation harness.
static func everything() -> ActionKit:
	var kit: ActionKit = starting()
	kit.unlocked.assign(ActionKind.Kind.values())
	return kit


func has(action: ActionKind.Kind) -> bool:
	return action in unlocked
