class_name ActionSession
extends RefCounted
## Action state that lasts one table session (spec §2.3). The table session
## (block 7) makes a fresh one each time the player sits down.

## Palm works once per session.
var palm_used: bool = false
## Marks made this session. Each one raises the next mark's cost (spec §2.3).
var marks_made: int = 0
## Manipulations in earlier hands that raised the side bets' value, this
## floor's carried in at sit-down. Each one raises the side-bet heat repeat
## (spec §8).
var side_bet_manipulations: int = 0
