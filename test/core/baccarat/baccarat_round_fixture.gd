class_name BaccaratRoundFixture
extends RefCounted
## Builds baccarat rounds from exact piles for the round suites. Piles are
## dealt in order: player, banker, player, banker, then the player's third
## card, then the banker's. Card i in the pile has id i.

const BET: int = 1000
## Wide table limits, so the ratio limits (spec §1.3) are the ones that bind.
const TABLE_MIN: int = 100
const TABLE_MAX: int = 100000

var config: TuneConfig = TuneConfig.load_default()
var rules: BaccaratRules = BaccaratRules.from_config(config)


## Dealt, in the initial window.
func dealt(
	codes: Array[String], side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER, stake: int = BET
) -> BaccaratRound:
	var pile: Array[Card] = []
	for code: String in codes:
		var card: Card = Card.parse(code)
		card.id = pile.size()
		pile.append(card)
	var limits: BetLimits = BetLimits.from_config(config, stake, TABLE_MIN, TABLE_MAX)
	var rnd: BaccaratRound = BaccaratRound.new(rules, side, limits, pile)
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
