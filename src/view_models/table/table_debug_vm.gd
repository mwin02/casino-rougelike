class_name TableDebugVM
extends RefCounted
## The debug table (U1): choose a table (setup), sit down, play hands with
## every action and adjust, and stand up. The deck, manipulation layer, kit,
## bankroll and run heat last for the whole app run, as they would across a
## run's tables.
##
## In a hand, game() draws the cards and picker() runs the actions; Next,
## the bet buttons and the game's buttons go through here, so a hand that
## resolves is settled at once. Its summary stays up until the next deal.
## Costs and the multiplier's workings are shown (reveal_costs).
##
## A window and the adjust after it are one step on screen: in the window the
## bet buttons set a pending bet and the actions stay live. Next closes both,
## making the pending bet in the adjust between them; a game button that acts
## in the adjust (Insure, Switch side, a High or Low call) closes the window
## the same way first. No action comes after an adjust, so the rules' order
## is unchanged.

enum Screen { SETUP, TABLE }

const END_TEXT: Dictionary[SessionEnd.Reason, String] = {
	SessionEnd.Reason.STOOD_UP: "You stood up",
	SessionEnd.Reason.BACKED_OFF: "You were backed off",
	SessionEnd.Reason.BROKE: "You went broke",
}

var setup: TableSetupVM
## The bet buttons at the current table, or null at setup.
var bets: TableBetVM
## The side bet buttons there (spec §8), or null at setup.
var side_bets: SideBetsVM
var bankroll: int
var run_heat: float = 0.0
var reveal_costs: bool = true

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


## How the last session ended, e.g. "You stood up: +$2,000 over 3 hands,
## +2.4 run heat". Empty before the first.
func end_text() -> String:
	if _end == null:
		return ""
	return "%s: %s over %d hands, %s run heat" % [
		END_TEXT[_end.reason],
		MoneyFormat.format_signed(_end.net),
		_end.hands_played,
		HeatText.amount(_end.run_heat_added),
	]


func in_hand() -> bool:
	return _session != null and _session.in_hand()


func can_deal() -> bool:
	return _session != null and _session.can_start_hand(bets.opening_bet, side_bets.bets())


func deal() -> void:
	if not can_deal():
		return
	var hand: HandActions = _session.start_hand(bets.opening_bet, bets.side, side_bets.bets())
	_game = GameTableVM.for_round(_session.current_round(), _layer)
	_picker = ActionPicker.new(hand, _kit, _game.card_label, reveal_costs)
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


## This hand's heat lines as they land, then the settled hand's.
func heat_lines() -> PackedStringArray:
	if _summary != null:
		return HeatText.lines_text(_summary.lines, reveal_costs)
	if in_hand():
		return HeatText.lines_text(_session.current_hand().heat.lines, reveal_costs)
	return PackedStringArray()


## "+$24,000 for 6 heat ($4,000 per heat)" once a hand settles, then how
## each side bet settled.
func summary_text() -> String:
	if _summary == null:
		return ""
	var lines: PackedStringArray = [HeatText.summary_text(_summary)]
	lines.append_array(SideBetsVM.result_lines(_summary.side_bets))
	return "\n".join(lines)


func status_lines() -> PackedStringArray:
	var lines: PackedStringArray = ["Bankroll " + MoneyFormat.format(bankroll)]
	if _session != null:
		var table: Table = _session.table
		var heat: TableHeat = _session.table_heat
		lines.append("%s, floor %d %s, %s–%s" % [
			TableSetupVM.GAME_NAMES[table.game],
			table.floor_number,
			TableSetupVM.STAKES_NAMES[table.stakes].to_lower(),
			MoneyFormat.format(table.table_min),
			MoneyFormat.format(table.table_max),
		])
		lines.append("Table heat %s (floor %s), %s" % [
			HeatText.number(heat.heat),
			HeatText.number(heat.heat_floor),
			HeatText.tier_name(heat.tier()),
		])
		lines.append("Session: %d hands, %s, %s heat" % [
			_session.hands_played,
			MoneyFormat.format_signed(_session.session_net),
			HeatText.number(_session.session_heat),
		])
		if _session.house_deck_swapped():
			lines.append("House deck")
	lines.append("Run heat " + HeatText.number(run_heat))
	return lines


## The table session to sit down at. Tests deal a stacked deck here.
func _new_session(table: Table, heat_floor: float) -> TableSession:
	return TableSession.new(
		_config, table, _deck, _layer, _kit, _rng, bankroll, heat_floor
	)


## The deck's heat floor (spec §4.2). Block 11 computes it from the deck's
## edits and marks; until then every session starts at 0.
func _heat_floor() -> float:
	return 0.0


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
