class_name WhaleBot
extends RevealBot
## The Whale (spec §10, §12): opens at the table maximum and never changes
## the bet, so the multiplier stays ×1. Its read pays through play: it
## full-reveals the key card each hand (the hole card, the player's second
## baccarat card, High or Low's next card) and plays or calls into it.


func _init() -> void:
	super("whale", false)


func opening_bet(session: TableSession) -> int:
	return mini(session.table.table_max, session.bankroll)
