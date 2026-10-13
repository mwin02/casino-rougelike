class_name SweepRow
extends RefCounted
## One thing a security sweep can take (spec §7.6): an owned item, or every
## mark of one symbol.

var choice: SweepChoice
## "Wax Pencil", or "Star".
var name: String
## The item's effect, or "7 marked cards".
var detail: String
## What else losing an item costs: "Takes 5 hands off this floor". Empty
## for most.
var warning: String = ""
## Up to three of a symbol's marked cards, to show.
var cards: Array[CardView] = []
var picked: bool = false
