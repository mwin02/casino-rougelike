class_name ShopMoney
extends RefCounted
## A shop's bankroll against the floor's quota (spec §6.2), as it stands
## mid-purchase: the shop holds the bankroll until the player leaves.

const UNDER_QUOTA: String = (
	"You're under the quota. Whatever you spend here has to be won back at the tables."
)
const OVER_QUOTA: String = "You're over the quota. Spending here comes out of your surplus."

var bankroll: int
var quota: int


func _init(p_bankroll: int, p_quota: int) -> void:
	bankroll = p_bankroll
	quota = p_quota


func bankroll_text() -> String:
	return MoneyFormat.format(bankroll)


## "Quota $140,000".
func quota_text() -> String:
	return "Quota " + MoneyFormat.format(quota)


func at_quota() -> bool:
	return bankroll >= quota


## "$43,500 short", or "Quota reached".
func gap_text() -> String:
	return FloorHudVM.REACHED if at_quota() else short_text(0) + " short"


## How far short of the quota spending cost would leave it: "$57,500";
## "$0" at or over it.
func short_text(cost: int) -> String:
	return MoneyFormat.format(maxi(quota - (bankroll - cost), 0))


func note() -> String:
	return OVER_QUOTA if at_quota() else UNDER_QUOTA


## The bankroll left after spending cost, then cost, each as a share of the
## quota: a bar's gold part and its striped part.
func shares(cost: int) -> Vector2:
	var whole: float = maxf(quota, 1.0)
	var left: float = clampf((bankroll - cost) / whole, 0.0, 1.0)
	return Vector2(left, clampf(bankroll / whole, 0.0, 1.0) - left)
