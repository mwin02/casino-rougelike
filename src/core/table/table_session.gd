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
##
## The session ends when the player stands up between hands, is backed off
## (after the hand that reaches 90, §7.1), or goes broke (below the table
## minimum). Ending rolls table heat above the floor into run heat (§7.3) and
## reverts session changes (§2.3).
##
## A house deck swap (§7.2) makes the table deal a standard deck from the
## next hand to the end of the session. Its card ids never match the owned
## deck's, so the player's edits, marks and taped changes don't reach it,
## and marking or sealing a house card is refused. High or Low prices
## against it.

## House deck card ids start here, far past any owned card's.
const HOUSE_ID_BASE: int = 1000000

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
var _ended: SessionEnd
## The casino's deck after a house deck swap, or null.
var _house_deck: Deck


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
		and _ended == null
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
	for line: HeatLine in summary.lines:
		if (
			line.kind == HeatLine.Kind.CONSEQUENCE
			and line.consequence == MarkedConsequence.Kind.HOUSE_DECK_SWAP
		):
			_house_deck = Deck.standard(0, HOUSE_ID_BASE)
			_priced_deck = _house_deck.cards()
	_hand.finish()
	bankroll += net
	session_net += net
	session_heat += summary.heat
	hands_played += 1
	_round = null
	_hand = null
	if table_heat.backed_off:
		_end(SessionEnd.Reason.BACKED_OFF)
	elif bankroll < table.table_min:
		_end(SessionEnd.Reason.BROKE)
	return summary


## Leaves the table between hands. Null mid-hand; once the session has
## ended, how it ended.
func stand_up() -> SessionEnd:
	if _ended == null and not in_hand():
		_end(SessionEnd.Reason.STOOD_UP)
	return _ended


## True once the pit has swapped in a house deck this session.
func house_deck_swapped() -> bool:
	return _house_deck != null


## How the session ended, or null while it's still going.
func ended() -> SessionEnd:
	return _ended


func _end(reason: SessionEnd.Reason) -> void:
	var key: String = (
		"backed_off_rollover" if reason == SessionEnd.Reason.BACKED_OFF else "stand_up_rollover"
	)
	var share: float = _config.get_float("run_heat", key)
	var above_floor: float = maxf(table_heat.heat - table_heat.heat_floor, 0.0)
	_layer.end_session()
	_ended = SessionEnd.new(reason, bankroll, above_floor * share, hands_played, session_net)


## A fresh shuffle of the table's deck as it reads now (§4.1).
func _pile() -> Array[Card]:
	return CardShuffle.shuffled(
		_dealing_deck().dealing_cards(_layer), _rng.stream(GameRng.Stream.SHUFFLE)
	)


## The house deck after a swap, otherwise the owned deck.
func _dealing_deck() -> Deck:
	return _house_deck if _house_deck != null else _deck
