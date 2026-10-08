class_name FloorSignature
extends RefCounted
## A floor's signature pressure (spec §5.3), leaning on one lever:
##
## - Watchful pit: every table's heat bases roll high, by a shift on both
##   ends of each roll range.
## - Stingy house: every table pays main-game winnings short. Side bets
##   (priced exactly, §8) and insurance (a hedge) keep their pay.
## - Short nights: a smaller hand clock.
##
## Floor 1 is the baseline. Floor 5 is the boss floor, whose house rule is
## [OPEN] (§5.3): BOSS is its hook and changes nothing yet.

enum Kind { BASELINE, WATCHFUL_PIT, STINGY_HOUSE, SHORT_NIGHTS, BOSS }

## The signatures an elevator offers for floors 2–4.
const POOL: Array[Kind] = [Kind.WATCHFUL_PIT, Kind.STINGY_HOUSE, Kind.SHORT_NIGHTS]

var kind: Kind
## Added to both ends of every roll range.
var roll_shift: float = 0.0
## Percent of main-game winnings paid.
var win_pct: int = 100
## Hands taken off the floor's clock.
var hand_cut: int = 0


static func of(config: TuneConfig, p_kind: Kind) -> FloorSignature:
	var signature: FloorSignature = FloorSignature.new()
	signature.kind = p_kind
	match p_kind:
		Kind.WATCHFUL_PIT:
			signature.roll_shift = config.get_float("signatures", "watchful_roll_shift")
		Kind.STINGY_HOUSE:
			signature.win_pct = config.get_int("signatures", "stingy_win_pct")
		Kind.SHORT_NIGHTS:
			signature.hand_cut = config.get_int("signatures", "short_nights_hand_cut")
	return signature


static func baseline() -> FloorSignature:
	var signature: FloorSignature = FloorSignature.new()
	signature.kind = Kind.BASELINE
	return signature


func apply_heat(rules: HeatRules) -> void:
	rules.shift_rolls(roll_shift)


## The floor's hands before items and bought hands.
func clock_hands(hands: int) -> int:
	return maxi(hands - hand_cut, 0)


## Dollars kept back from one winning stake's winnings, rounding the pay
## down (§6.2).
func house_cut(winnings: int) -> int:
	return winnings - Money.apply_ratio(winnings, win_pct, 100)
