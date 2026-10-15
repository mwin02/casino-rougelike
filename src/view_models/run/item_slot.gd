class_name ItemSlot
extends RefCounted
## One of the kit's item slots (spec §9): the item in it, or empty.

var filled: bool = false
var info: ItemInfo


static func of(kit: ActionKit, config: TuneConfig) -> Array[ItemSlot]:
	var slots: Array[ItemSlot] = []
	var count: int = maxi(ItemRules.from_config(config).slots, kit.items.size())
	for i: int in count:
		var slot: ItemSlot = ItemSlot.new()
		if i < kit.items.size():
			slot.filled = true
			slot.info = ItemInfo.of(kit.items[i], config)
		slots.append(slot)
	return slots


## "2 / 6 SLOTS".
static func count_text(kit: ActionKit, config: TuneConfig) -> String:
	return "%d / %d SLOTS" % [kit.items.size(), ItemRules.from_config(config).slots]
