class_name BetLimits
extends RefCounted
## How far a hand's total bet may move (spec §1.3). Limits are measured
## against the opening bet, never the current one, and apply to the total bet:
## doubles, splits and insurance count toward them like an adjust does.

const SECTION: String = "heat"
const NO_CAP: int = -1

## The stake placed at the stake window.
var opening: int
var table_min: int
var table_max: int
## The total bet stays at or under this percent of the opening bet...
var max_raise_pct: int
## ...and at or over this percent of it.
var min_decrease_pct: int
## The total bet never passes the player's bankroll, or NO_CAP. The table
## session sets it each hand.
var bankroll_cap: int = NO_CAP


func _init(
	p_opening: int, p_table_min: int, p_table_max: int, p_max_raise_pct: int, p_min_decrease_pct: int
) -> void:
	opening = p_opening
	table_min = p_table_min
	table_max = p_table_max
	max_raise_pct = p_max_raise_pct
	min_decrease_pct = p_min_decrease_pct


## Table min and max come from the table the hand is played at.
static func from_config(
	config: TuneConfig, p_opening: int, p_table_min: int, p_table_max: int
) -> BetLimits:
	return BetLimits.new(
		p_opening,
		p_table_min,
		p_table_max,
		config.get_int(SECTION, "max_raise_pct"),
		config.get_int(SECTION, "min_decrease_pct"),
	)


## The largest total bet allowed.
func max_total() -> int:
	var cap: int = mini(Money.apply_ratio(opening, max_raise_pct, 100), table_max)
	return cap if bankroll_cap == NO_CAP else mini(cap, bankroll_cap)


## The smallest total bet allowed. Rounds up, so it never dips under the ratio.
func min_total() -> int:
	return maxi(-Money.apply_ratio(-opening, min_decrease_pct, 100), table_min)


func allows(total: int) -> bool:
	return total >= min_total() and total <= max_total()
