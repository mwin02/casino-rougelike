class_name HeatReceipt
extends RefCounted
## A hand's heat as the real table lists it (spec §1.4): one row per action
## and bet change, each its final heat as a whole number, with an action's
## side-bet heat (§8) folded into its row. The multiplier's effect is its
## own Bet size row, shown only when the bet grew against the opening bet
## and the row isn't 0. Cooling is a row too, outside the hand's total.
##
## Each row is rounded on its own and the total is rounded once, so Bet size
## shows the total less the other rows: with it, the rows sum to the total.
## Nothing here says how a number was made up.

const BET_SIZE: String = "Bet size"
const COOLING: String = "Straight hand"
const RAISED: String = "Raised bet"
const LOWERED: String = "Lowered bet"

## The hand's rows, in the order they landed.
var rows: Array[Row] = []
## The hand's own heat: every row but cooling.
var total: int = 0
## What the table did after the hand: a new tier, the Marked consequence,
## a back-off.
var notices: PackedStringArray = []


class Row:
	extends RefCounted
	var label: String
	var amount: int

	func _init(p_label: String, p_amount: int) -> void:
		label = p_label
		amount = p_amount

	## Signed: "+12", "-6".
	func amount_text() -> String:
		return ("+%d" if amount > 0 else "%d") % amount


func _init(lines: Array[HeatLine]) -> void:
	var exact: float = 0.0
	var amounts: Array[float] = []
	var cooling: float = 0.0
	var ratio: float = 1.0
	for line: HeatLine in lines:
		match line.kind:
			HeatLine.Kind.ACTION:
				rows.append(Row.new(HeatText.action_name(line.action), 0))
				amounts.append(line.amount)
			HeatLine.Kind.BET_CHANGE:
				rows.append(Row.new(_bet_change_label(line), 0))
				amounts.append(line.amount)
			HeatLine.Kind.SIDE_BET:
				# Charged with the manipulation just before it.
				amounts[-1] += line.amount
			HeatLine.Kind.MULTIPLIER:
				ratio = line.ratio
			HeatLine.Kind.COOLING:
				cooling += line.amount
				continue
			_:
				notices.append(HeatText.line_text(line, false))
				continue
		exact += line.amount
	total = roundi(exact)
	var shown: int = 0
	for i: int in rows.size():
		rows[i].amount = roundi(amounts[i])
		shown += rows[i].amount
	if ratio > 1.0 and total != shown:
		rows.append(Row.new(BET_SIZE, total - shown))
	if roundi(cooling) != 0:
		rows.append(Row.new(COOLING, roundi(cooling)))


static func _bet_change_label(line: HeatLine) -> String:
	if line.bet_change == BetChange.Kind.ADJUST:
		return RAISED if line.bet_delta >= 0 else LOWERED
	return HeatText.BET_CHANGE_NAMES[line.bet_change]
