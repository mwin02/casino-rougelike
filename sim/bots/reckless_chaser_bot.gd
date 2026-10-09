class_name RecklessChaserBot
extends RevealBot
## The reckless chaser (spec §7.4, §12): acts and adjusts in every window. It
## full-reveals a face-down card in each window, plays into what it saw, and
## raises to the largest bet at every adjust.


func _init() -> void:
	super("reckless_chaser", true)


## Reckless: sits until backed off (§7.4, §12).
func stands_up() -> bool:
	return false


## Chases the quota and cashes out on reaching it.
func run_plan() -> RunPlan:
	return RunPlan.of(actions_used(), [], 100)


func on_window(session: TableSession, hand: HandActions) -> void:
	reveal_subject(session.current_round(), hand)


func on_adjust(session: TableSession, _hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	rnd.adjust(rnd.adjust_max())
