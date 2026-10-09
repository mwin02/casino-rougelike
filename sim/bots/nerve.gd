class_name Nerve
extends RefCounted
## A simulated player's nerve (spec §12): the table heat they stand up at.
## Each player draws theirs once, between MIN and MAX: cautious ones leave
## while the table is Watched, bold ones ride into Marked. Each session moves
## it by up to JITTER either way. These describe players, not the game, so
## they live here rather than in config.

const MIN: float = 35.0
const MAX: float = 85.0
const JITTER: float = 5.0

## This player's stand-up heat before the session's jitter.
var heat: float

## Its own stream, so a run's cards don't change with the player drawn.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func draw(seed: int) -> Nerve:
	var nerve: Nerve = Nerve.new()
	nerve._rng.seed = hash("nerve:%d" % seed)
	nerve.heat = nerve._rng.randf_range(MIN, MAX)
	return nerve


## The stand-up heat for the next session.
func session_heat() -> float:
	return heat + _rng.randf_range(-JITTER, JITTER)
