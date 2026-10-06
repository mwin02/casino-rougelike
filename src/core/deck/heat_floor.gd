class_name HeatFloor
extends RefCounted
## The deviation heat floor (spec §4.2): every table session starts at it
## and can't cool below it. It counts edits, not edge, so removing a card and
## adding it back is two steps. The session fixes it at sit-down; a mark or
## seal made during the session counts from the next one.


static func of(deck: Deck, kit: ActionKit, rules: DeckRules) -> float:
	var total: float = 0.0
	for edit: DeckEdit in deck.edits():
		total += rules.floor_per_edit(edit.kind)
	for card: Card in deck.cards():
		if not card.is_marked():
			continue
		if card.symbol in kit.luminous_symbols:
			total += rules.floor_per_luminous_mark
		else:
			total += rules.floor_per_mark
	if kit.forged_papers:
		total -= rules.forged_papers_floor_cut
	return maxf(total, 0.0)
