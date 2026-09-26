class_name BaccaratRoundFixture
extends RefCounted
## Builds baccarat rounds from exact piles for the round suites. Piles are
## dealt in order: player, banker, player, banker, then the player's third
## card, then the banker's.

const BET: int = 1000

var rules: BaccaratRules = BaccaratRules.from_config(TuneConfig.load_default())


## Dealt, in the initial window.
func dealt(
	codes: Array[String], side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER, stake: int = BET
) -> BaccaratRound:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	var rnd: BaccaratRound = BaccaratRound.new(rules, side, stake, pile)
	rnd.deal()
	return rnd


## Passes every window and adjust until the round resolves. Returns the
## windows that opened, in order.
static func play_out(rnd: BaccaratRound) -> Array[BaccaratRound.WindowKind]:
	var windows: Array[BaccaratRound.WindowKind] = []
	while rnd.phase != BaccaratRound.Phase.RESOLVED:
		if rnd.phase == BaccaratRound.Phase.WINDOW:
			windows.append(rnd.window)
		rnd.proceed()
	return windows
