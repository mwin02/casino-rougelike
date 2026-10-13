class_name ReserveMoney
extends RefCounted
## The end shop's bankroll (spec §6.5): what it holds, the next floor's
## low-stakes minimum it never spends below, and what that leaves to spend.

var bankroll: int
var reserve: int

## The bankroll the shop opened with: the whole of the bar.
var _opened_with: int
var _quota: int


func _init(p_bankroll: int, p_reserve: int, opened_with: int, quota: int) -> void:
	bankroll = p_bankroll
	reserve = p_reserve
	_opened_with = maxi(opened_with, 1)
	_quota = quota


func bankroll_text() -> String:
	return MoneyFormat.format(bankroll)


## "Floor $5,000": the floor under the spending.
func reserve_text() -> String:
	return "Floor " + MoneyFormat.format(reserve)


## What can be spent: "$163,400".
func spend_text() -> String:
	return MoneyFormat.format(maxi(bankroll - reserve, 0))


## The bankroll as a share of what the shop opened with, 0 to 1.
func bankroll_share() -> float:
	return _share(bankroll)


## Where the reserve sits on that bar.
func reserve_share() -> float:
	return _share(reserve)


## Where the quota just passed sits on it.
func quota_share() -> float:
	return _share(_quota)


func _share(amount: int) -> float:
	return clampf(float(amount) / _opened_with, 0.0, 1.0)
