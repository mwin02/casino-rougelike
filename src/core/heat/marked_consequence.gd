class_name MarkedConsequence
extends RefCounted
## What happens when a table first crosses into Marked (spec §7.2).

enum Kind {
	## The table deals the casino's standard deck for the rest of the session.
	HOUSE_DECK_SWAP,
	## The table's base cost rolls are redrawn.
	NEW_DEALER,
}
