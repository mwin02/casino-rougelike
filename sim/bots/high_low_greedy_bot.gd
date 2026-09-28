class_name HighLowGreedyBot
extends Bot
## High or Low greedy (spec §12): the table minimum, no actions, and chases
## the chain: after each win it calls again while the better side wins at
## least CONTINUE_ODDS of the remaining cards.

const CONTINUE_ODDS: float = 0.6


func bot_name() -> String:
	return "high_low_greedy"


func plays(game: GameKind.Kind) -> bool:
	return game == GameKind.Kind.HIGH_LOW


func continue_high_low(_session: TableSession, _hand: HandActions, rnd: HighLowRound) -> bool:
	var best: int = maxi(
		rnd.winners(HighLowRound.Direction.HIGHER), rnd.winners(HighLowRound.Direction.LOWER)
	)
	return rnd.remaining() > 0 and float(best) / rnd.remaining() >= CONTINUE_ODDS
