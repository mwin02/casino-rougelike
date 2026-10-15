class_name KitAction
extends RefCounted
## One window action on the kit screen (spec §2.3, §2.4): unlocked or not,
## and where it comes from.

## "Full reveal".
var name: String
## "Starting kit", "Shaded Lenses", or "Needs Mirror Ring".
var source: String
var locked: bool
