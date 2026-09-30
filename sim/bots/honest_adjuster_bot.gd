class_name HonestAdjusterBot
extends Bot
## The honest adjuster (spec §1.1, §12): opens at the table minimum, never
## acts, and sizes the bet on the cards showing. Its result is the check on
## the bet-change base. At the first adjust of a hand (baccarat and High or
## Low have only the one) it values the bet: worth more than RAISE_ABOVE per
## unit, it goes to the largest bet allowed (switching to the better baccarat
## side first); worth less than LOWER_BELOW, to the smallest; otherwise it
## stays.

## Value per unit staked that sizes the bet up or down.
const RAISE_ABOVE: float = 0.0
const LOWER_BELOW: float = -0.25

var _baccarat_rules: BaccaratRules
var _baccarat_odds: Array[float] = []


func bot_name() -> String:
	return "honest_adjuster"


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_baccarat_rules = BaccaratRules.from_config(config)
	_baccarat_odds = BaccaratOdds.value_odds(deck.cards())


func on_adjust(session: TableSession, _hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	if rnd is BlackjackRound and rnd.window_number == 1:
		_size(rnd, _blackjack_value(rnd as BlackjackRound))
	elif rnd is BaccaratRound:
		var baccarat: BaccaratRound = rnd
		var outcomes: Array[float] = _baccarat_outcomes(baccarat)
		var other: BaccaratRound.BetSide = (
			BaccaratRound.BetSide.PLAYER
			if baccarat.side == BaccaratRound.BetSide.BANKER
			else BaccaratRound.BetSide.BANKER
		)
		var other_value: float = BaccaratOdds.side_value(outcomes, other, _baccarat_rules)
		if other_value > RAISE_ABOVE and baccarat.can_switch_side():
			baccarat.switch_side()
		_size(rnd, BaccaratOdds.side_value(outcomes, baccarat.side, _baccarat_rules))
	elif rnd is HighLowRound:
		var high_low: HighLowRound = rnd
		_size(rnd, high_low_value(high_low) / high_low.chain_value)


## The first call's value in dollars, from what the bot knows.
func high_low_value(rnd: HighLowRound) -> float:
	return HighLowOdds.call_value(rnd, HighLowOdds.best_direction(rnd))


## True when the bot knows this dealt card: index is its place in its
## baccarat hand, shown how many of those have turned over.
func knows(_card: Card, index: int, shown: int) -> bool:
	return index < shown


## Largest bet above RAISE_ABOVE, smallest below LOWER_BELOW.
func _size(rnd: GameRound, value: float) -> void:
	if value > RAISE_ABOVE:
		rnd.adjust(rnd.adjust_max())
	elif value < LOWER_BELOW:
		rnd.adjust(rnd.adjust_min())


## The hand's value played without doubling or splitting: at the largest
## bet, the raise cap leaves no room for either.
func _blackjack_value(rnd: BlackjackRound) -> float:
	return strategy.hand_value(
		rnd.active_hand().cards, rnd.dealer_hand.cards[0], hole_odds(rnd), false, false
	)


## Before the second cards turn over, only each side's first card shows.
## Known cards count up to the first unknown one on each side.
func _baccarat_outcomes(rnd: BaccaratRound) -> Array[float]:
	var shown: int = 3 if rnd.second_cards_shown else 1
	var sides: Array[Array] = []
	for hand: BaccaratHand in [rnd.player_hand, rnd.banker_hand]:
		var values: Array[int] = []
		for index: int in hand.cards.size():
			if not knows(hand.cards[index], index, shown):
				break
			values.append(BaccaratHand.value(hand.cards[index]))
		sides.append(values)
	return BaccaratOdds.outcomes(sides[0], sides[1], _baccarat_odds)
