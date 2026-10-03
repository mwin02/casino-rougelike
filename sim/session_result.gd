class_name SessionResult
extends RefCounted
## What one measurement session came to.

var net: int = 0
## Action, bet-change and multiplier heat (HandSummary.heat); cooling is not
## counted.
var heat: float = 0.0
## Heat the table shed to cooling after straight hands, as a positive number
## (HandSummary.cooling is negative).
var cooling: float = 0.0
var hands: int = 0
## Sum of the opening bets and side bets.
var staked: int = 0
var end_reason: SessionEnd.Reason = SessionEnd.Reason.STOOD_UP
var run_heat_added: float = 0.0
