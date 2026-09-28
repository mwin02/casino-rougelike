class_name MinBetCoolerBot
extends RevealBot
## The min-bet cooler (spec §1.6, §12): the cheat-then-cool sawtooth. Odd
## hands open at the table maximum and play into one full reveal; even hands
## are straight at the table minimum, cooling the table.

var _hands: int = 0


func _init() -> void:
	super("min_bet_cooler", false)


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_hands = 0


func opening_bet(session: TableSession) -> int:
	_hands += 1
	if _cooling():
		return session.table.table_min
	return mini(session.table.table_max, session.bankroll)


func on_window(session: TableSession, hand: HandActions) -> void:
	if not _cooling():
		super(session, hand)


func _cooling() -> bool:
	return _hands % 2 == 0
