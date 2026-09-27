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


func _init(
	p_reason: Reason, p_bankroll: int, p_run_heat_added: float, p_hands_played: int, p_net: int
) -> void:
	reason = p_reason
	bankroll = p_bankroll
	run_heat_added = p_run_heat_added
	hands_played = p_hands_played
	net = p_net
