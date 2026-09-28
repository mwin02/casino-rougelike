class_name HighLowOdds
extends RefCounted
## The value of a High or Low call (spec §3.3) from what the table shows: the
## remaining cards it prices against, and the price of a win. A tie keeps
## half the chain; a loss keeps nothing.


## Expected chain value after calling direction, less the chain value now.
static func call_value(rnd: HighLowRound, direction: HighLowRound.Direction) -> float:
	var remaining: int = rnd.remaining()
	if remaining == 0:
		return 0.0
	var wins: int = rnd.winners(direction)
	var ties: int = (
		remaining
		- rnd.winners(HighLowRound.Direction.HIGHER)
		- rnd.winners(HighLowRound.Direction.LOWER)
	)
	var won: float = float(wins) * rnd.value_if_won(direction)
	var tied: float = float(ties) * HighLowRules.tie_value(rnd.chain_value)
	return (won + tied) / remaining - rnd.chain_value


## The call worth more; higher on a tie.
static func best_direction(rnd: HighLowRound) -> HighLowRound.Direction:
	var higher: float = call_value(rnd, HighLowRound.Direction.HIGHER)
	var lower: float = call_value(rnd, HighLowRound.Direction.LOWER)
	return HighLowRound.Direction.HIGHER if higher >= lower else HighLowRound.Direction.LOWER
