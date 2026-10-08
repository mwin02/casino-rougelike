class_name SessionEnd
extends RefCounted
## How a table session ended and what it left behind (spec §7.3): the
## bankroll, and the run heat its table heat rolled into.

enum Reason {
	## The player left between hands.
	STOOD_UP,
	## Table heat reached 90 (§7.1).
	BACKED_OFF,
	## The bankroll fell below the table minimum.
	BROKE,
}

var reason: Reason
var bankroll: int
## Table heat above the floor × the rollover share.
var run_heat_added: float
## Hands played at the table. Each one cost a clock tick (§6.1).
var hands_played: int
## Dollars won (or lost) at the table.
var net: int
## Hand heat spent at the table (HandSummary.heat); cooling not counted.
var session_heat: float = 0.0


func _init(
	p_reason: Reason, p_bankroll: int, p_run_heat_added: float, p_hands_played: int, p_net: int
) -> void:
	reason = p_reason
	bankroll = p_bankroll
	run_heat_added = p_run_heat_added
	hands_played = p_hands_played
	net = p_net


func to_dict() -> Dictionary:
	return {
		"reason": reason,
		"bankroll": bankroll,
		"run_heat_added": run_heat_added,
		"hands_played": hands_played,
		"net": net,
		"session_heat": session_heat,
	}


static func from_dict(saved: Dictionary) -> SessionEnd:
	var p_reason: int = saved["reason"]
	var p_bankroll: int = saved["bankroll"]
	var p_run_heat_added: float = saved["run_heat_added"]
	var p_hands_played: int = saved["hands_played"]
	var p_net: int = saved["net"]
	var end: SessionEnd = SessionEnd.new(
		p_reason as Reason, p_bankroll, p_run_heat_added, p_hands_played, p_net
	)
	end.session_heat = saved["session_heat"]
	return end
