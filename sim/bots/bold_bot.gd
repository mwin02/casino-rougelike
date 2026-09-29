class_name BoldBot
extends Bot
## Bold play (spec §12): the table maximum (or the whole bankroll, if less)
## every hand, no actions, no bet changes.


func bot_name() -> String:
	return "bold"


func opening_bet(session: TableSession) -> int:
	return mini(session.table.table_max, session.bankroll)
