class_name TableDebugVM
extends TableFlowVM
## The debug table (U1): the table flow written out as plain text, with
## every cost's workings shown (reveal_workings).

const END_TEXT: Dictionary[SessionEnd.Reason, String] = {
	SessionEnd.Reason.STOOD_UP: "You stood up",
	SessionEnd.Reason.BACKED_OFF: "You were backed off",
	SessionEnd.Reason.BROKE: "You went broke",
}


func _init(config: TuneConfig, deck: Deck, rng: GameRng) -> void:
	super(config, deck, rng)
	reveal_workings = true


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


func heat_lines() -> PackedStringArray:
	return HeatText.lines_text(hand_lines(), reveal_workings)


## "+$24,000 for 6 heat ($4,000 per heat)" once a hand settles, then what
## items added and how each side bet settled.
func summary_text() -> String:
	if _summary == null:
		return ""
	var lines: PackedStringArray = [HeatText.summary_text(_summary)]
	lines.append_array(ItemText.bonus_lines(_summary.bonuses))
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
		var ledger: PitLedger = _session.ledger()
		if ledger != null:
			lines.append(ItemText.ledger_text(ledger))
		lines.append("Session: %d hands, %s, %s heat" % [
			_session.hands_played,
			MoneyFormat.format_signed(_session.session_net),
			HeatText.number(_session.session_heat),
		])
		if _session.house_deck_swapped():
			lines.append("House deck")
		if not table.house_rule.is_empty():
			lines.append(HouseRuleText.offer_line(table.house_rule))
	lines.append("Run heat " + HeatText.number(run_heat))
	return lines
