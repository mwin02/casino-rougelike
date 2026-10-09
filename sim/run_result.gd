class_name RunResult
extends RefCounted
## What one run played by a bot came to (spec §7.4, §11, §12).

## How the run ended (§11): won, ejected, short at a quota check the marker
## couldn't cover, or broke at a table once it was used (or on floor 5).
enum End { UNFINISHED, WON, EJECTED, SHORT, BROKE }

## The run reached an end: won or lost.
var finished: bool = false
var end: End = End.UNFINISHED
var won: bool = false
## Lost to run heat (§7.4).
var ejected: bool = false
## The floor the run ended on, 1–5.
var floor_reached: int = 1
var bankroll: int = 0
## The highest run heat reached, and where it ended.
var peak_run_heat: float = 0.0
var run_heat: float = 0.0
## §11: the run's dollars per heat.
var dollars_per_heat: float = 0.0
## Hands played across every floor, and on each floor 1–5.
var hands: int = 0
var hands_by_floor: Array[int] = [0, 0, 0, 0, 0]
## The bankroll entering each floor 1–5 (§6.3); 0 for floors not reached.
var floor_bankrolls: Array[int] = [0, 0, 0, 0, 0]
