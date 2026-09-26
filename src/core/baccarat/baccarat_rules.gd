class_name BaccaratRules
extends RefCounted
## Baccarat payouts (spec §3.2) and the fixed third-card rules. Player pays
## 1:1 and a tie pushes Player and Banker bets; those are fixed rules.

const SECTION: String = "baccarat"
## Passed to banker_draws() when the player took no third card.
const NO_THIRD: int = -1

## A banker win pays 1:1 less this percent.
var banker_commission_pct: int
## A tie bet pays tie_payout_num : tie_payout_den.
var tie_payout_num: int
var tie_payout_den: int


static func from_config(config: TuneConfig) -> BaccaratRules:
	var rules: BaccaratRules = BaccaratRules.new()
	rules.banker_commission_pct = config.get_int(SECTION, "banker_commission_pct")
	rules.tie_payout_num = config.get_int(SECTION, "tie_payout_num")
	rules.tie_payout_den = config.get_int(SECTION, "tie_payout_den")
	return rules


## The player draws a third card on 0–5 and stands on 6–7.
static func player_draws(player_total: int) -> bool:
	return player_total <= 5


## player_third is the value of the player's third card, or NO_THIRD.
static func banker_draws(banker_total: int, player_third: int) -> bool:
	if player_third == NO_THIRD:
		return banker_total <= 5
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third != 8
		4:
			return player_third >= 2 and player_third <= 7
		5:
			return player_third >= 4 and player_third <= 7
		6:
			return player_third == 6 or player_third == 7
	return false
