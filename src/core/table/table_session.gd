class_name TableSession
extends RefCounted
## One sitting at one table (block 7): sit down, play hands, stand up.
##
## Sitting down rolls the table's costs and its hidden Marked consequence
## (spec §1.2, §7.2), starts table heat at the heat floor (§4.2), starts a
## fresh ActionSession, and captures the owned deck for High or Low pricing
## (§3.3). Each hand deals a fresh shuffle of the deck as it reads under the
## manipulation layer (§4.1). Finishing a hand settles its net into the
## bankroll and lands its heat. No bet passes the bankroll.

var table: Table
var bankroll: int
var table_heat: TableHeat
var hands_played: int = 0
## Dollars won (or lost) this session.
var session_net: int = 0
## Action and multiplier heat this session. Cooling is not counted.
var session_heat: float = 0.0

var _config: TuneConfig
var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _rng: GameRng
var _action_session: ActionSession = ActionSession.new()
## §3.3: the owned deck as it stood at sit-down.
var _priced_deck: Array[Card]
var _round: GameRound
var _hand: HandActions


## heat_floor comes from the deck's deviation (§4.2).
func _init(
	config: TuneConfig,
	p_table: Table,
	deck: Deck,
	layer: ManipulationLayer,
	kit: ActionKit,
	rng: GameRng,
	p_bankroll: int,
	heat_floor: float
) -> void:
	_config = config
	table = p_table
	_deck = deck
	_layer = layer
	_kit = kit
	_rng = rng
	bankroll = p_bankroll
	var rules: HeatRules = HeatRules.from_config(config)
	var costs: TableCosts = TableCosts.roll(
		rules, table.game, table.stakes, rng.stream(GameRng.Stream.TABLE_ROLLS)
	)
	table_heat = TableHeat.start(rules, costs, heat_floor, table.floor_number, rng)
	_priced_deck = deck.cards()


## True between start_hand() and finish_hand().
func in_hand() -> bool:
	return _round != null


## The opening bet must sit within the table and the bankroll.
func can_start_hand(opening_bet: int) -> bool:
	return (
		not in_hand()
		and opening_bet >= table.table_min
		and opening_bet <= table.table_max
		and opening_bet <= bankroll
	)


## Deals a hand at opening_bet and returns its actions, or null when refused.
## side is the baccarat bet; other games ignore it.
func start_hand(
	opening_bet: int, side: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER
) -> HandActions:
	if not can_start_hand(opening_bet):
		return null
	var limits: BetLimits = BetLimits.from_config(
		_config, opening_bet, table.table_min, table.table_max
	)
	limits.bankroll_cap = bankroll
	var pile: Array[Card] = _pile()
	match table.game:
		GameKind.Kind.BLACKJACK:
			var blackjack: BlackjackRound = BlackjackRound.new(
				BlackjackRules.from_config(_config), limits, pile
			)
			blackjack.deal()
			_round = blackjack
		GameKind.Kind.BACCARAT:
			var baccarat: BaccaratRound = BaccaratRound.new(
				BaccaratRules.from_config(_config), side, limits, pile
			)
			baccarat.deal()
			_round = baccarat
		GameKind.Kind.HIGH_LOW:
			var high_low: HighLowRound = HighLowRound.new(
				HighLowRules.from_config(_config), limits, _priced_deck, pile
			)
			high_low.deal()
			_round = high_low
	_hand = HandActions.new(
		_round, _deck, _layer, _kit, _action_session, table_heat.start_hand(_action_session)
	)
	return _hand


## The round being played, or null between hands.
func current_round() -> GameRound:
	return _round


## The hand's actions, or null between hands.
func current_hand() -> HandActions:
	return _hand


## Settles a resolved hand: its net goes into the bankroll and its heat onto
## the table. Null while no resolved hand is in play.
func finish_hand() -> HandSummary:
	if not in_hand() or not _round.is_resolved():
		return null
	var straight: bool = TableHeat.is_straight(_hand.heat, _round)
	var net: int = _round.net()
	var summary: HandSummary = HandSummary.new(
		net, table_heat.finish_hand(_hand.heat, _round), straight
	)
	_hand.finish()
	bankroll += net
	session_net += net
	session_heat += summary.heat
	hands_played += 1
	_round = null
	_hand = null
	return summary


## A fresh shuffle of the deck as it reads now (§4.1).
func _pile() -> Array[Card]:
	return CardShuffle.shuffled(
		_deck.dealing_cards(_layer), _rng.stream(GameRng.Stream.SHUFFLE)
	)
