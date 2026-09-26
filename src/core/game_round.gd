class_name GameRound
extends RefCounted
## What every game's round shares: the bet limits and bet changes, the bet
## lock (spec §2.2), and the count of windows opened this hand. Each game
## fills in its own windows and what an adjust moves.

## The stake placed at the stake window. Bet changes are measured against it.
var opening_bet: int
var limits: BetLimits
var bet_changes: Array[BetChange] = []
## Windows opened this hand, the current one included.
var window_number: int = 0

var _bet_locked: bool = false


func _init(p_limits: BetLimits) -> void:
	limits = p_limits
	opening_bet = p_limits.opening


## After a manipulation (spec §2.2): no more bet changes this hand.
func lock_bet() -> void:
	_bet_locked = true


func is_bet_locked() -> bool:
	return _bet_locked


## True while a window is open.
func in_window() -> bool:
	return false


## Every dollar on the table now.
func total_bet() -> int:
	return 0


## True in an adjust, while the bet isn't locked.
func can_adjust() -> bool:
	return false


## The smallest total bet an adjust may set now.
func adjust_min() -> int:
	return limits.min_total()


## The largest total bet an adjust may set now.
func adjust_max() -> int:
	return limits.max_total()


## Raises or lowers the bet to new_total, recorded as a bet change. Does
## nothing outside an adjust, past a limit, or without a change.
func adjust(new_total: int) -> void:
	if not can_adjust() or new_total < adjust_min() or new_total > adjust_max():
		return
	var amount: int = new_total - total_bet()
	if amount == 0:
		return
	_apply_adjust(amount)
	bet_changes.append(BetChange.new(BetChange.Kind.ADJUST, amount, _adjust_hand_index()))


## Moves amount dollars onto (or off) the bet.
func _apply_adjust(_amount: int) -> void:
	push_error("GameRound._apply_adjust: not implemented")


## The hand an adjust belongs to, or BetChange.NO_HAND.
func _adjust_hand_index() -> int:
	return BetChange.NO_HAND


## Each game calls this when a window opens.
func _count_window() -> void:
	window_number += 1
