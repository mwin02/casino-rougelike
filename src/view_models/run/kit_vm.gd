class_name KitVM
extends RefCounted
## The kit between tables (block U4, spec §2.4, §9): the items in their
## slots, one picked to read and to discard (two presses, no refund), the
## actions they unlock, the symbols with their marks, and what else is
## held.

const NONE: int = -1
const STARTING: String = "Starting kit"
const DISCARD: String = "Discard"
const DISCARD_SURE: String = "Tap again to discard"
const NO_REFUND: String = "No refund."
const SEATED: String = "Can't discard right now."
const EMPTY_TITLE: String = "Empty slot"
const EMPTY_NOTE: String = "Shops sell items you don't own. Buying needs a free slot."

var _owner: RunVM
var _run: Run
var _kit: ActionKit
var _picked: int = NONE
## Discard has been pressed once.
var _armed: bool = false


## owner's run is on the map.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_kit = _run.kit
	if not _kit.items.is_empty():
		_picked = 0


## "FLOOR 2 · BETWEEN TABLES".
func heading() -> String:
	return "FLOOR %d · BETWEEN TABLES" % _run.state.floor_number


func slots() -> Array[ItemSlot]:
	return ItemSlot.of(_kit, _run.config())


func slots_text() -> String:
	return ItemSlot.count_text(_kit, _run.config())


## The slot picked, or NONE.
func picked() -> int:
	return _picked


func pick(index: int) -> void:
	_picked = index
	_armed = false


## The picked item, or null on an empty slot.
func picked_item() -> ItemInfo:
	if _picked < 0 or _picked >= _kit.items.size():
		return null
	return ItemInfo.of(_kit.items[_picked], _run.config())


## What discarding the picked item costs: "No refund. Full reveal locks
## again."
func discard_note() -> String:
	var info: ItemInfo = picked_item()
	if info == null:
		return ""
	if not _run.floor.can_discard():
		return SEATED
	var cost: String = ItemLoss.cost(info.kind, _run)
	if ItemKind.UNLOCKS.has(info.kind):
		cost = "%s locks again" % HeatText.action_name(ItemKind.UNLOCKS[info.kind])
	elif cost.is_empty() and ItemKind.SYMBOLS.has(info.kind):
		cost = "You lose its symbol"
	return NO_REFUND if cost.is_empty() else "%s %s." % [NO_REFUND, cost]


func can_discard() -> bool:
	return picked_item() != null and _run.floor.can_discard()


func discard_label() -> String:
	return DISCARD_SURE if _armed else DISCARD


## The first press asks; the second discards the picked item.
func press_discard() -> void:
	var info: ItemInfo = picked_item()
	if not can_discard():
		return
	if not _armed:
		_armed = true
		return
	_armed = false
	if _run.floor.discard_item(info.kind):
		_picked = mini(_picked, _kit.items.size() - 1)
		_owner.step_done()


## The deck as it stands, with the heat floor it gives every table.
func deck() -> DeckViewVM:
	var rules: DeckRules = DeckRules.from_config(_run.config())
	return DeckViewVM.new(
		_run.game.deck, _run.game.layer, _kit, HeatFloor.of(_run.game.deck, _kit, rules)
	)


## The knowledge actions, unlocked or not.
func knowledge() -> Array[KitAction]:
	return _actions(ActionKind.KNOWLEDGE)


func manipulation() -> Array[KitAction]:
	return _actions(ActionKind.MANIPULATION)


## The symbols the player can mark with, and any other still on a card
## (its pencil discarded), with how many cards wear each.
func symbols() -> Array[LegendRow]:
	var counts: Dictionary[int, int] = {}
	for symbol: int in _kit.symbols:
		counts[symbol] = 0
	for card: Card in _run.game.deck.cards():
		if card.is_marked():
			counts[card.symbol] = counts.get(card.symbol, 0) + 1
	var ids: Array[int] = counts.keys()
	ids.sort()
	var rows: Array[LegendRow] = []
	for symbol: int in ids:
		rows.append(LegendRow.new(symbol, counts[symbol], false))
	return rows


## What else is held, each a name and an amount: "Masking Tape", "×2".
func held() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = [
		PackedStringArray(["Masking Tape", "×%d" % _kit.masking_tape]),
		PackedStringArray(["Cold Seal", "×%d" % _kit.cold_seals]),
	]
	if _kit.has_item(ItemKind.Kind.PERMANENT_INK):
		var most: int = ItemRules.from_config(_run.config()).ink_charges_per_floor
		rows.append(PackedStringArray(["Ink charges", "%d / %d" % [_kit.ink_charges, most]]))
	return rows


func _actions(family: Array[ActionKind.Kind]) -> Array[KitAction]:
	var rows: Array[KitAction] = []
	for action: ActionKind.Kind in family:
		var row: KitAction = KitAction.new()
		row.name = HeatText.action_name(action)
		row.locked = not _kit.has(action)
		row.source = STARTING
		var item: Variant = ItemKind.UNLOCKS.find_key(action)
		if item != null:
			var item_name: String = ItemKind.NAMES[item]
			row.source = "Needs " + item_name if row.locked else item_name
		rows.append(row)
	return rows
