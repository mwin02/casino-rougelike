class_name SweepVM
extends RefCounted
## The security sweep on screen (block U4, spec §7.6): run heat crossed the
## sweep threshold, and the player picks what to lose, one owned item or
## every mark of one symbol, then confirms. The floor goes on from there.

const SHOWN_CARDS: int = 3
const PICK: String = "Choose what to lose"
const HINT: String = "One item, or every mark of one symbol."

var _owner: RunVM
var _run: Run
var _floor: Floor
var _picked: SweepChoice


## owner's run is at a sweep.
func _init(owner: RunVM) -> void:
	_owner = owner
	_run = owner.run
	_floor = _run.floor


func hud() -> FloorHudVM:
	return FloorHudVM.new(_run)


func slots_text() -> String:
	return ItemSlot.count_text(_run.kit, _run.config())


## Slots with no item in them.
func empty_slots() -> int:
	return maxi(ItemRules.from_config(_run.config()).slots - _run.kit.items.size(), 0)


func items() -> Array[SweepRow]:
	var rows: Array[SweepRow] = []
	for choice: SweepChoice in _floor.sweep_choices():
		if choice.kind != SweepChoice.Kind.ITEM:
			continue
		var info: ItemInfo = ItemInfo.of(choice.item, _run.config())
		var row: SweepRow = _row(choice, info.name, info.effect)
		row.warning = _warning(choice.item)
		rows.append(row)
	return rows


func symbols() -> Array[SweepRow]:
	var rows: Array[SweepRow] = []
	for choice: SweepChoice in _floor.sweep_choices():
		if choice.kind != SweepChoice.Kind.SYMBOL:
			continue
		var marked: Array[Card] = _marked(choice.symbol)
		var row: SweepRow = _row(
			choice, CardText.symbol_word(choice.symbol),
			"%d marked %s" % [marked.size(), "card" if marked.size() == 1 else "cards"]
		)
		for card: Card in marked.slice(0, SHOWN_CARDS):
			row.cards.append(CardView.new(card, false, false))
		rows.append(row)
	return rows


func pick(choice: SweepChoice) -> void:
	_picked = choice


func can_confirm() -> bool:
	return _picked != null


## "Lose Late Night", "Lose star marks", or "Choose what to lose".
func confirm_text() -> String:
	if _picked == null:
		return PICK
	if _picked.kind == SweepChoice.Kind.ITEM:
		return "Lose " + ItemKind.NAMES[_picked.item]
	return "Lose %s marks" % CardText.symbol_word(_picked.symbol).to_lower()


## What the pick costs, in a line.
func note() -> String:
	if _picked == null:
		return HINT
	if _picked.kind == SweepChoice.Kind.ITEM:
		var warning: String = _warning(_picked.item)
		var lost: String = "You lose %s." % ItemKind.NAMES[_picked.item]
		return lost if warning.is_empty() else "%s %s." % [lost, warning]
	var count: int = _marked(_picked.symbol).size()
	return "%d %s %s. Your heat floor drops from the next session." % [
		count,
		"card loses its" if count == 1 else "cards lose their",
		CardText.symbol_word(_picked.symbol).to_lower(),
	]


## Gives the pick up and goes on with the floor.
func confirm() -> void:
	if _picked != null and _floor.sweep(_picked):
		_owner.step_done()


func _row(choice: SweepChoice, name: String, detail: String) -> SweepRow:
	var row: SweepRow = SweepRow.new()
	row.choice = choice
	row.name = name
	row.detail = detail
	row.picked = _picked != null and _picked.same_as(choice)
	return row


## Losing Late Night takes its hands off this floor at once, and losing
## Permanent Ink its charges (§7.6).
func _warning(item: ItemKind.Kind) -> String:
	if item == ItemKind.Kind.LATE_NIGHT:
		var hands: int = ItemRules.from_config(_run.config()).late_night_hands
		return "Takes %d hands off this floor" % hands
	var charges: int = _run.kit.ink_charges
	if item == ItemKind.Kind.PERMANENT_INK and charges > 0:
		return "Loses its %d %s" % [charges, "charge" if charges == 1 else "charges"]
	return ""


func _marked(symbol: int) -> Array[Card]:
	var marked: Array[Card] = []
	for card: Card in _run.game.deck.cards():
		if card.symbol == symbol:
			marked.append(card)
	return marked
