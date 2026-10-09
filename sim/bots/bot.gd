class_name Bot
extends RefCounted
## A simulated player (spec §12). The session runner opens each hand at
## opening_bet() and play_hand() drives it to resolution, handing the bot's
## hooks each decision: the windows, the adjusts, and each game's plays.
##
## A bot sees only what a player sees: the round's face-up cards, what its
## own actions reveal, and the table's public numbers. It never reads the
## pile (GameRound.upcoming) except through look_ahead(), and never reads a
## face-down card except through a reveal. Nothing enforces this; every bot
## keeps to it.

## A hand that takes more decisions than this is stuck.
const MAX_STEPS: int = 500

## Blackjack plays, priced on the owned deck.
var strategy: BlackjackEv
## The table heat this session stands up at (§12); INF sits until the
## session ends.
var stand_up_heat: float = INF


## The name the harness knows this bot by.
func bot_name() -> String:
	push_error("Bot.bot_name: not implemented")
	return ""


## False for a game the bot has no policy for; the harness skips it there.
func plays(_game: GameKind.Kind) -> bool:
	return true


## Called when the bot sits down on deck, before the first hand.
func begin_session(_session: TableSession, config: TuneConfig, deck: Deck) -> void:
	strategy = BlackjackEv.from_cards(BlackjackRules.from_config(config), deck.cards())


## False for reckless play, which sits until backed off (§7.4, §12).
func stands_up() -> bool:
	return true


## Sets this session's stand-up heat from the player's nerve.
func take_nerve(nerve: Nerve) -> void:
	if stands_up():
		stand_up_heat = nerve.session_heat()


## The actions this bot's policy takes (§2.3).
func actions_used() -> Array[ActionKind.Kind]:
	return []


## How it plays a run off the tables.
func run_plan() -> RunPlan:
	return RunPlan.of(actions_used())


## True once table heat reaches this session's stand-up heat.
func wants_to_stand(session: TableSession) -> bool:
	return session.table_heat.heat >= stand_up_heat


func opening_bet(session: TableSession) -> int:
	return session.table.table_min


## The side bets to place with the opening bet (§8). None by default.
func side_bets(_session: TableSession) -> Array[SideBet]:
	return []


## Banker carries the smaller house edge.
func baccarat_side(_session: TableSession) -> BaccaratRound.BetSide:
	return BaccaratRound.BetSide.BANKER


## Plays the hand the session just dealt until it resolves.
func play_hand(session: TableSession, hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	var steps: int = 0
	while not rnd.is_resolved():
		steps += 1
		if steps > MAX_STEPS:
			push_error("Bot.play_hand: %s is stuck" % bot_name())
			return
		if rnd is BlackjackRound:
			_step_blackjack(session, hand, rnd as BlackjackRound)
		elif rnd is BaccaratRound:
			_step_baccarat(session, hand, rnd as BaccaratRound)
		elif rnd is HighLowRound:
			_step_high_low(session, hand, rnd as HighLowRound)


## An open window: the bot may act. The window closes afterwards.
func on_window(_session: TableSession, _hand: HandActions) -> void:
	pass


## An adjust: the bot may move the bet, switch sides or insure.
func on_adjust(_session: TableSession, _hand: HandActions) -> void:
	pass


## Blackjack's turn: must hit, stand, double or split. The strategy's best
## play for what the bot knows of the hole card.
func play_blackjack(_session: TableSession, _hand: HandActions, rnd: BlackjackRound) -> void:
	var play: BlackjackEv.Play = strategy.decide(
		rnd.active_hand().cards,
		rnd.dealer_hand.cards[0],
		hole_odds(rnd),
		rnd.can_double(),
		rnd.can_split()
	)
	match play:
		BlackjackEv.Play.STAND:
			rnd.stand()
		BlackjackEv.Play.HIT:
			rnd.hit()
		BlackjackEv.Play.DOUBLE:
			rnd.double()
		BlackjackEv.Play.SPLIT:
			rnd.split()


## What the bot knows of the dealer's hole card: by default, only the deck.
func hole_odds(_rnd: BlackjackRound) -> Array[float]:
	return strategy.deck_odds()


## High or Low: the call worth more at its price.
func call_high_low(
	_session: TableSession, _hand: HandActions, rnd: HighLowRound
) -> HighLowRound.Direction:
	return HighLowOdds.best_direction(rnd)


## High or Low after a correct call: true continues the chain, false banks.
func continue_high_low(_session: TableSession, _hand: HandActions, _rnd: HighLowRound) -> bool:
	return false


func _step_blackjack(session: TableSession, hand: HandActions, rnd: BlackjackRound) -> void:
	match rnd.phase:
		BlackjackRound.Phase.WINDOW:
			on_window(session, hand)
			rnd.proceed()
		BlackjackRound.Phase.ADJUST:
			on_adjust(session, hand)
			rnd.proceed()
		BlackjackRound.Phase.PLAYER_TURN:
			play_blackjack(session, hand, rnd)


func _step_baccarat(session: TableSession, hand: HandActions, rnd: BaccaratRound) -> void:
	if rnd.phase == BaccaratRound.Phase.WINDOW:
		on_window(session, hand)
	else:
		on_adjust(session, hand)
	rnd.proceed()


func _step_high_low(session: TableSession, hand: HandActions, rnd: HighLowRound) -> void:
	match rnd.phase:
		HighLowRound.Phase.WINDOW:
			on_window(session, hand)
			rnd.proceed()
		HighLowRound.Phase.ADJUST:
			on_adjust(session, hand)
			rnd.proceed()
		HighLowRound.Phase.CALL:
			rnd.call_next(call_high_low(session, hand, rnd))
		HighLowRound.Phase.DECIDE:
			if continue_high_low(session, hand, rnd):
				rnd.continue_chain()
			else:
				rnd.bank()

