class_name HonestAdjusterBot
extends Bot
## The honest adjuster (spec §1.1, §12): opens at the table minimum, never
## acts, and sizes the bet on the cards showing. Its result is the check on
## the bet-change base. At the first adjust of a hand (blackjack, High or
## Low) or at every adjust (baccarat, where more cards show each time) it
## values the bet: worth more than RAISE_ABOVE per unit, it goes to the
## largest bet allowed (switching to the better baccarat side first);
## worth less than LOWER_BELOW, to the smallest; otherwise it stays.

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
		var best: HighLowRound.Direction = HighLowOdds.best_direction(high_low)
		_size(rnd, HighLowOdds.call_value(high_low, best) / high_low.chain_value)


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
		rnd.active_hand().cards, rnd.dealer_hand.cards[0], strategy.deck_odds(), false, false
	)


## Before the second cards turn over, only each side's first card shows.
func _baccarat_outcomes(rnd: BaccaratRound) -> Array[float]:
	var shown: int = 3 if rnd.second_cards_shown else 1
	var player: Array[int] = []
	var banker: Array[int] = []
	for card: Card in rnd.player_hand.cards.slice(0, shown):
		player.append(BaccaratHand.value(card))
	for card: Card in rnd.banker_hand.cards.slice(0, shown):
		banker.append(BaccaratHand.value(card))
	return BaccaratOdds.outcomes(player, banker, _baccarat_odds)
