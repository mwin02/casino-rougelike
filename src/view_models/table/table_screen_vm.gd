class_name TableScreenVM
extends TableFlowVM
## The real table screen (U2) on the table flow: which stage of a hand the
## screen is at, the HUD, the heat meter and the open window's panel. Every
## heat number here is final and whole (spec §1.4).
##
## A settled hand stays up until the player continues, even when it ended
## the session, so its result and heat are read before the table is left.

enum Stage { CHOOSE, STAKE, WINDOW, TURN, SETTLE }

const BET_OPEN: String = "Raise or lower your bet before play."
const BET_LOCKED: String = "Your bet is locked."
const NO_ACTIONS: String = "Nothing to use here"

var _rules: HeatRules
## The table as the last hand started and settled, kept past the session.
var _table: Table
var _heat_before: float = 0.0
var _heat_after: float = 0.0
var _heat_floor_now: float = 0.0


func _init(config: TuneConfig, deck: Deck, rng: GameRng) -> void:
	super(config, deck, rng)
	_rules = HeatRules.from_config(config)


func stage() -> Stage:
	if in_hand():
		return Stage.WINDOW if _game.game_round().in_window() else Stage.TURN
	if _summary != null:
		return Stage.SETTLE
	return Stage.STAKE if _session != null else Stage.CHOOSE


func sit_down() -> void:
	super()
	if _session != null:
		_table = _session.table
		_heat_floor_now = _session.table_heat.heat_floor
		_heat_before = _session.table_heat.heat
		_heat_after = _heat_before


func deal() -> void:
	if can_deal():
		_heat_before = _session.table_heat.heat
		_heat_after = _heat_before
	super()


## Continue: puts the settled hand away, back to the stake window, or to
## choosing a table if the hand ended the session.
func continue_after_hand() -> void:
	if not in_hand():
		_summary = null


## "Blackjack"; empty before the first table.
func title() -> String:
	return TableSetupVM.GAME_NAMES[_table.game] if _table != null else ""


## "FLOOR 1 · LOW STAKES".
func subtitle() -> String:
	if _table == null:
		return ""
	var stakes: String = TableSetupVM.STAKES_NAMES[_table.stakes]
	return ("Floor %d · %s" % [_table.floor_number, stakes]).to_upper()


func bankroll_text() -> String:
	return MoneyFormat.format(bankroll)


## "$1,000–$4,000".
func limits_text() -> String:
	if _table == null:
		return ""
	return "%s–%s" % [MoneyFormat.format(_table.table_min), MoneyFormat.format(_table.table_max)]


## What the felt has printed on it: the game, then the table's house rule
## if it has one. Upper case.
func felt_lines() -> PackedStringArray:
	if _table == null:
		return []
	var lines: PackedStringArray = [title().to_upper()]
	if not _table.house_rule.is_empty():
		lines.append(HouseRuleText.offer_line(_table.house_rule).to_upper())
	return lines


## Hands left on the floor clock (spec §6.1). Empty until the floor screens
## (U4) run the table.
func clock_text() -> String:
	return ""


## The table's heat, with this hand's heat so far as pending. Once the hand
## settles it shows where the table ended up.
func meter() -> HeatMeterVM:
	var pending: float = 0.0
	if in_hand():
		pending = _session.current_hand().heat.total() + _picker.weighed_cost()
	return HeatMeterVM.new(_rules, _heat_after, _heat_floor_now, pending)


## The table's heat when the settled hand began, for the settle panel.
func meter_before() -> HeatMeterVM:
	return HeatMeterVM.new(_rules, _heat_before, _heat_floor_now)


## The hand's heat as rows, as it lands and once settled.
func receipt() -> HeatReceipt:
	return HeatReceipt.new(hand_lines())


## What's about to go on the table, or null away from a table.
func stake() -> StakeVM:
	return StakeVM.new(_session, bets, side_bets) if _session != null else null


## The settled hand's result, or null while there is none to show.
func result() -> HandResultVM:
	if stage() != Stage.SETTLE:
		return null
	return HandResultVM.new(_game, _summary, receipt())


## The open window's subject, e.g. "HOLE CARD". Empty outside a window.
func window_tag() -> String:
	return _game.window_tag().to_upper() if stage() == Stage.WINDOW else ""


## What the window is about, then whether the bet can still move.
func window_note() -> String:
	if stage() != Stage.WINDOW:
		return ""
	var rnd: GameRound = _game.game_round()
	return "%s %s" % [_game.window_note(), BET_OPEN if rnd.adjust_ahead() else BET_LOCKED]


## "Read or rig · from +2 heat": the cheapest action that can be used now.
func eye_text() -> String:
	if stage() != Stage.WINDOW:
		return ""
	var hand: HandActions = _session.current_hand()
	var cheapest: float = INF
	for action: ActionKind.Kind in ActionKind.Kind.values():
		if hand.can_use(action):
			cheapest = minf(cheapest, hand.cost_of(action))
	if cheapest == INF:
		return NO_ACTIONS
	return "Read or rig · from +%d heat" % roundi(cheapest)


## The real table's picker names cards in words, shows whole-number costs,
## and tells the game which face-down cards the player has seen.
func _new_picker(hand: HandActions) -> ActionPicker:
	var picker: ActionPicker = ActionPicker.new(hand, _kit, _game.target_name)
	picker.for_screen = true
	_game.peeked = picker.peeked
	return picker


func _hand_settled() -> void:
	_heat_after = _session.table_heat.heat
