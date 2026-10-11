class_name TableFlowVM
extends RefCounted
## What both table screens run on: choose a table (setup), sit down, play
## hands with every action and adjust, and stand up. The deck, manipulation
## layer, kit, bankroll and run heat last for the whole app run, as they
## would across a run's tables. The screens add what they show.
##
## In a hand, game() draws the cards and picker() runs the actions; Next,
## the bet buttons and the game's buttons go through here, so a hand that
## resolves is settled at once. Its summary stays up until the next deal.
##
## A window and the adjust after it are one step on screen: in the window the
## bet buttons set a pending bet and the actions stay live. Next closes both,
## making the pending bet in the adjust between them; a game button that acts
## in the adjust (Insure, Switch side, a High or Low call) closes the window
## the same way first. No action comes after an adjust, so the rules' order
## is unchanged.

enum Screen { SETUP, TABLE }

var setup: TableSetupVM
## The bet buttons at the current table, or null at setup.
var bets: TableBetVM
## The side bet buttons there (spec §8), or null at setup.
var side_bets: SideBetsVM
var bankroll: int
var run_heat: float = 0.0
## Shows how each heat number is made up. Only the debug table does (spec
## §1.4); an action's final cost shows either way.
var reveal_workings: bool = false

var _config: TuneConfig
var _deck: Deck
var _layer: ManipulationLayer = ManipulationLayer.new()
var _rng: GameRng
var _session: TableSession
## The kit the session sat down with. Setup can swap its own between tables.
var _kit: ActionKit
var _game: GameTableVM
var _picker: ActionPicker
var _summary: HandSummary
var _end: SessionEnd


func _init(config: TuneConfig, deck: Deck, rng: GameRng) -> void:
	_config = config
	_deck = deck
	_rng = rng
	setup = TableSetupVM.new(config)
	bankroll = config.get_int("floors", "start_bankroll")


func screen() -> Screen:
	return Screen.TABLE if _session != null else Screen.SETUP


func can_sit_down() -> bool:
	return screen() == Screen.SETUP and bankroll >= setup.table().table_min


func sit_down() -> void:
	if not can_sit_down():
		return
	_kit = setup.kit
	_session = _new_session(setup.table(), _heat_floor())
	bets = TableBetVM.new(_session)
	side_bets = SideBetsVM.new(_session)
	_game = null
	_picker = null
	_summary = null
	_end = null


func in_hand() -> bool:
	return _session != null and _session.in_hand()


func can_deal() -> bool:
	return _session != null and _session.can_start_hand(bets.opening_bet, side_bets.bets())


func deal() -> void:
	if not can_deal():
		return
	var hand: HandActions = _session.start_hand(bets.opening_bet, bets.side, side_bets.bets())
	_game = GameTableVM.for_round(_session.current_round(), _layer)
	_picker = ActionPicker.new(hand, _kit, _game.card_label)
	_summary = null
	bets.start_hand(_game)
	_settle()


func can_stand_up() -> bool:
	return _session != null and not _session.in_hand()


func stand_up() -> void:
	if can_stand_up():
		_leave(_session.stand_up())


## The table session, or null at setup.
func session() -> TableSession:
	return _session


## The hand on the table (the last one once it's settled), or null.
func game() -> GameTableVM:
	return _game


## This hand's actions (the last hand's once it's settled), or null.
func picker() -> ActionPicker:
	return _picker


## The settled hand's summary, until the next deal. Null before then.
func summary() -> HandSummary:
	return _summary


## How the last session ended, or null before the first ends.
func ended() -> SessionEnd:
	return _end


## This hand's heat lines as they land, then the settled hand's.
func hand_lines() -> Array[HeatLine]:
	if _summary != null:
		return _summary.lines
	if in_hand():
		return _session.current_hand().heat.lines
	return []


func can_proceed() -> bool:
	return in_hand() and _game.can_proceed()


## Next: closes the open window, and the adjust after it, or the adjust.
func proceed() -> void:
	if not can_proceed():
		return
	var rnd: GameRound = _game.game_round()
	if rnd.in_window():
		var through_adjust: bool = rnd.adjust_follows()
		_close_window()
		if through_adjust:
			_game.proceed()
	else:
		_game.proceed()
	_settle()


## A bet button: the opening bet, a pending bet in a window, or the bet in
## an adjust.
func press_bet(id: int) -> void:
	if _session != null:
		bets.press(id)


## The game's own buttons while a hand is in play.
func play_choices() -> Array[Choice]:
	return _game.play_choices() if in_hand() else ([] as Array[Choice])


## A game button. Only an enabled one acts.
func play(id: int) -> void:
	var enabled: bool = false
	for choice: Choice in play_choices():
		enabled = enabled or (choice.id == id and choice.enabled)
	if enabled:
		if _game.closes_window(id):
			_close_window()
		_game.play(id)
		_settle()


## The table session to sit down at. Tests deal a stacked deck here.
func _new_session(table: Table, heat_floor: float) -> TableSession:
	return TableSession.new(
		_config, table, _deck, _layer, _kit, _rng, bankroll, heat_floor
	)


## The deck's heat floor (spec §4.2), fixed for the session at sit-down.
func _heat_floor() -> float:
	return HeatFloor.of(_deck, _kit, DeckRules.from_config(_config))


## Settles the hand once it resolves, and leaves if the session ended.
func _settle() -> void:
	_picker.reset()
	if not _session.current_round().is_resolved():
		return
	_summary = _session.finish_hand()
	bankroll = _session.bankroll
	bets.end_hand()
	if _session.ended() != null:
		_leave(_session.ended())


## Closes the open window: into its adjust, making the pending bet there,
## or past it when no adjust follows.
func _close_window() -> void:
	var rnd: GameRound = _game.game_round()
	if not rnd.in_window():
		return
	var adjust_follows: bool = rnd.adjust_follows()
	_game.proceed()
	if adjust_follows:
		bets.commit()


func _leave(ended: SessionEnd) -> void:
	_end = ended
	bankroll = ended.bankroll
	run_heat += ended.run_heat_added
	_session = null
	bets = null
	side_bets = null
