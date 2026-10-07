class_name ItemPayouts
extends RefCounted
## What items add to a settled hand's main bet (spec §9). Side bets never
## take a bonus.
##
## - Signature: each winning stake with a marked card among the player's
##   cards that won it pays its percent more, once however many are marked.
## - High Roller's Nerve: with the total bet above the table's midpoint, the
##   winnings pay its percent more.
## - Comp Slip: the session's first hand, if its main bet loses, gets back
##   what it lost, at most the opening stake. Insurance doesn't count.
##
## Each winning stake counts on its own: a split hand that wins takes its
## bonus even if another hand of the round lost.


static func of(kit: ActionKit, rnd: GameRound, table: Table, first_hand: bool) -> Array[ItemBonus]:
	var bonuses: Array[ItemBonus] = []
	var signature: int = 0
	var winnings: int = 0
	for win: RoundWin in rnd.wins():
		winnings += win.winnings
		if win.has_marked_card():
			signature += Money.apply_ratio(win.winnings, kit.signature_pct, 100)
	if signature > 0:
		bonuses.append(ItemBonus.new(ItemKind.Kind.SIGNATURE, signature))
	if kit.high_roller_pct > 0 and rnd.total_bet() * 2 > table.table_min + table.table_max:
		var nerve: int = Money.apply_ratio(winnings, kit.high_roller_pct, 100)
		if nerve > 0:
			bonuses.append(ItemBonus.new(ItemKind.Kind.HIGH_ROLLERS_NERVE, nerve))
	var main: int = rnd.main_net()
	if kit.comp_slip and first_hand and main < 0:
		bonuses.append(ItemBonus.new(ItemKind.Kind.COMP_SLIP, mini(-main, rnd.opening_bet)))
	return bonuses
