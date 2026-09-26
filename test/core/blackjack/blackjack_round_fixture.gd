class_name BlackjackRoundFixture
extends RefCounted
## Builds blackjack rounds from exact piles for the round suites. Piles are
## dealt in order: player, dealer up, player, dealer hole, then player draws in
## the order they happen, then the dealer's draws.

const BET: int = 1000

var rules: BlackjackRules = BlackjackRules.from_config(TuneConfig.load_default())


## Dealt, but still in the hole-card window.
func dealt(codes: Array[String]) -> BlackjackRound:
	var pile: Array[Card] = []
	for code: String in codes:
		pile.append(Card.parse(code))
	var rnd: BlackjackRound = BlackjackRound.new(rules, BET, pile)
	rnd.deal()
	return rnd


## Dealt and past the hole-card window and its adjust: the player's turn.
func at_turn(codes: Array[String]) -> BlackjackRound:
	var rnd: BlackjackRound = dealt(codes)
	rnd.proceed()
	rnd.proceed()
	return rnd


## Hit through its window and adjust.
static func hit(rnd: BlackjackRound) -> void:
	rnd.hit()
	pass_draw(rnd)


## Double through its window and adjust.
static func double(rnd: BlackjackRound) -> void:
	rnd.double()
	pass_draw(rnd)


## Passes the window and adjust in front of a hit or double card.
static func pass_draw(rnd: BlackjackRound) -> void:
	rnd.proceed()
	rnd.proceed()


## Stand the last hand and pass the final window.
static func stand(rnd: BlackjackRound) -> void:
	rnd.stand()
	rnd.proceed()
