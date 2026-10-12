class_name HandResultVM
extends RefCounted
## A settled hand on the real table's settle panel: the verdict, where the
## dollars came from row by row, and the efficiency line (spec §1.4):
## "+$24,000 for 6 heat". The rows always sum to the hand's net.

const MAIN_BET: String = "Main bet"
const HOUSE_CUT: String = "House cut"

## "You win", or one outcome per split hand.
var verdict: String
var payouts: Array[Payout] = []
var net: int
## The hand's heat as its receipt shows it.
var heat: int


class Payout:
	extends RefCounted
	var label: String
	var dollars: int

	func _init(p_label: String, p_dollars: int) -> void:
		label = p_label
		dollars = p_dollars

	## "+$4,000", "-$500".
	func amount_text() -> String:
		return MoneyFormat.format_signed(dollars)

	func is_loss() -> bool:
		return dollars < 0


func _init(game: GameTableVM, summary: HandSummary, receipt: HeatReceipt) -> void:
	verdict = game.outcome_text()
	net = summary.net
	heat = receipt.total
	var main: int = summary.net - summary.side_net + summary.house_cut
	for bonus: ItemBonus in summary.bonuses:
		main -= bonus.dollars
	payouts.append(Payout.new(MAIN_BET, main))
	for bet: SideBet in summary.side_bets:
		payouts.append(Payout.new(SideBetsVM.NAMES[bet.kind], bet.net()))
	for bonus: ItemBonus in summary.bonuses:
		payouts.append(Payout.new(ItemKind.NAMES[bonus.item], bonus.dollars))
	if summary.house_cut > 0:
		payouts.append(Payout.new(HOUSE_CUT, -summary.house_cut))


func net_text() -> String:
	return MoneyFormat.format_signed(net)


func is_loss() -> bool:
	return net < 0


## "+$24,000 for 6 heat", or "-$1,000, no heat".
func efficiency_text() -> String:
	if heat <= 0:
		return net_text() + ", no heat"
	return "%s for %d heat" % [net_text(), heat]
