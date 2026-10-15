class_name ItemLoss
extends RefCounted
## What losing an item costs beyond the item itself (spec §7.6, §9),
## whether it is discarded or taken by a security sweep.


## "Takes 5 hands off this floor", "Loses its 2 charges", or empty for an
## item that just goes. Late Night takes only the hands the clock still
## holds; Luminous Ink's marks go back to counting in full.
static func cost(item: ItemKind.Kind, run: Run) -> String:
	if item == ItemKind.Kind.LATE_NIGHT:
		var late: int = ItemRules.from_config(run.config()).late_night_hands
		var hands: int = mini(late, run.floor.clock.hands_left)
		if hands == 0:
			return ""
		return "Takes %d %s off this floor" % [hands, "hand" if hands == 1 else "hands"]
	if item == ItemKind.Kind.LUMINOUS_INK:
		return "Its marks count in full on the heat floor"
	var charges: int = run.kit.ink_charges
	if item == ItemKind.Kind.PERMANENT_INK and charges > 0:
		return "Loses its %d %s" % [charges, "charge" if charges == 1 else "charges"]
	return ""
