class_name RecklessChaserBot
extends RevealBot
## The reckless chaser (spec §7.4, §12): acts and adjusts in every window. It
## full-reveals a face-down card in each window, plays into what it saw, and
## raises to the largest bet at every adjust.


func _init() -> void:
	super("reckless_chaser", true)


func on_window(session: TableSession, hand: HandActions) -> void:
	reveal_subject(session.current_round(), hand)


func on_adjust(session: TableSession, _hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	rnd.adjust(rnd.adjust_max())
