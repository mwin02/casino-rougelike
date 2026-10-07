class_name QuotaCheck
extends RefCounted
## The quota check at the end of a floor's walk (spec §6.2, §11).

enum Result {
	## The bankroll reached the quota; the player gets the elevator key card.
	PASSED,
	## The marker fronted the shortfall.
	MARKER,
	## Short, and the marker couldn't cover it. The run is over.
	LOST,
	## Floor 5's quota reached. The run is won.
	WON,
}

var result: Result
## Dollars the marker fronted at this check.
var fronted: int


func _init(p_result: Result, p_fronted: int = 0) -> void:
	result = p_result
	fronted = p_fronted


func passed() -> bool:
	return result != Result.LOST
