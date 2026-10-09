class_name FloorResult
extends RefCounted
## What one floor played by a bot came to.

## The bankroll reached the quota before the clock ran out (§6.2).
var cleared: bool = false
## Hands spent from the floor's clock.
var hands: int = 0
var bankroll: int = 0
## Run heat the floor's tables rolled over (§7.3).
var run_heat: float = 0.0
## Tables sat at.
var tables: int = 0
## Tables left on reaching the player's nerve (§12).
var stood_up: int = 0
