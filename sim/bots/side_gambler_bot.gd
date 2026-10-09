class_name SideGamblerBot
extends Bot
## Side-bet gambler (spec §8, §12): the table minimum every hand, no actions,
## no bet changes, and every side bet the game offers at the cap, as many as
## the bankroll covers. Dragon Bonus and Pair go on the Player side (Dragon
## Bonus's smaller edge); exact rank calls a 7.

const CALLED_RANK: int = 7


func bot_name() -> String:
	return "side_gambler"


## Keeps its block 10 behaviour: sits until the session ends.
func stands_up() -> bool:
	return false


## Chases the quota and cashes out on reaching it.
func cash_out_pct() -> int:
	return 100


func side_bets(session: TableSession) -> Array[SideBet]:
	var cap: int = session.side_bet_cap()
	var room: int = session.bankroll - opening_bet(session)
	var bets: Array[SideBet] = []
	for kind: SideBetKind.Kind in SideBetKind.for_game(session.table.game):
		if room < cap:
			break
		room -= cap
		match kind:
			SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR:
				bets.append(SideBet.on_side(kind, cap, BaccaratRound.BetSide.PLAYER))
			SideBetKind.Kind.EXACT_RANK:
				bets.append(SideBet.exact_rank(cap, CALLED_RANK))
			_:
				bets.append(SideBet.new(kind, cap))
	return bets
