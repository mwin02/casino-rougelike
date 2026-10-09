class_name RunScore
extends RefCounted
## A run's score (spec §11): the final bankroll, and dollars per heat over
## the whole run: the bankroll's gain over the start, per point of hand heat
## (§1.4: action, side-bet, bet-change and multiplier) spent at every table.

var bankroll: int
## The bankroll's gain over the starting bankroll (negative for a loss).
var profit: int
var heat_spent: float
## 0 when the run spent no heat.
var dollars_per_heat: float = 0.0


static func of(state: RunState) -> RunScore:
	var score: RunScore = RunScore.new()
	score.bankroll = state.bankroll
	score.profit = state.bankroll - state.start_bankroll
	score.heat_spent = state.heat_spent
	if state.heat_spent > 0.0:
		score.dollars_per_heat = score.profit / state.heat_spent
	return score
