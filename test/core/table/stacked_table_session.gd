class_name StackedTableSession
extends TableSession
## A table session that deals the deck in its own order every hand, so a
## suite knows exactly which card comes when. Card i has id i.


func _pile() -> Array[Card]:
	return _dealing_deck().dealing_cards(_layer)
