class_name ActionSession
extends RefCounted
## Action state that lasts one table session (spec §2.3). The table session
## (block 7) makes a fresh one each time the player sits down.

## Palm works once per session.
var palm_used: bool = false
## Marks made this session. Each one raises the next mark's cost (spec §2.3).
var marks_made: int = 0
