class_name SimReport
extends RefCounted
## Dollars per heat per game (spec §3.4, §12): one record per config
## variant, game and bot. Heat is summed in fixed point, so merging shards in
## any order gives the same totals and the same printed report.
##
## Raw dollars per heat is net / heat. Marginal dollars per heat is what the
## bot gains per hand over straight_flat, same variant and game, per heat:
## the number the §3.4 1.5× target is read from.

const BASELINE: String = "straight_flat"
## Heat is kept in units of 1 / HEAT_SCALE.
const HEAT_SCALE: float = 10000.0


class Record:
	var variant_index: int
	var variant: String
	var game: GameKind.Kind
	var bot_index: int
	var bot: String
	var sessions: int = 0
	var hands: int = 0
	var net: int = 0
	var staked: int = 0
	var heat_units: int = 0
	var backed_off: int = 0

	func ev_per_hand() -> float:
		return float(net) / hands if hands > 0 else 0.0

	func heat_per_hand() -> float:
		return heat_units / HEAT_SCALE / hands if hands > 0 else 0.0

	## Net as a share of the opening bets.
	func edge() -> float:
		return float(net) / staked if staked > 0 else 0.0

	## Net per heat, or 0 when the bot spent none.
	func dollars_per_heat() -> float:
		return net / (heat_units / HEAT_SCALE) if heat_units > 0 else 0.0

	func key() -> String:
		return SimReport.key_of(variant_index, game, bot)


var _records: Dictionary[String, Record] = {}


static func key_of(variant_index: int, game: GameKind.Kind, bot: String) -> String:
	return "%d|%d|%s" % [variant_index, game, bot]


func add(
	variant_index: int,
	variant: String,
	game: GameKind.Kind,
	bot_index: int,
	bot: String,
	result: SessionResult
) -> void:
	var key: String = key_of(variant_index, game, bot)
	if not _records.has(key):
		var fresh: Record = Record.new()
		fresh.variant_index = variant_index
		fresh.variant = variant
		fresh.game = game
		fresh.bot_index = bot_index
		fresh.bot = bot
		_records[key] = fresh
	var record: Record = _records[key]
	record.sessions += 1
	record.hands += result.hands
	record.net += result.net
	record.staked += result.staked
	record.heat_units += roundi(result.heat * HEAT_SCALE)
	if result.end_reason == SessionEnd.Reason.BACKED_OFF:
		record.backed_off += 1


## The record for this variant, game and bot, or null.
func record(variant_index: int, game: GameKind.Kind, bot: String) -> Record:
	return _records.get(key_of(variant_index, game, bot))


## Every record: variant, then game, then bot, in run order.
func records() -> Array[Record]:
	var result: Array[Record] = []
	result.assign(_records.values())
	result.sort_custom(
		func(a: Record, b: Record) -> bool:
			if a.variant_index != b.variant_index:
				return a.variant_index < b.variant_index
			if a.game != b.game:
				return a.game < b.game
			return a.bot_index < b.bot_index
	)
	return result


## (EV per hand − straight_flat's) / heat per hand. 0 without heat or a
## baseline.
func marginal_dollars_per_heat(rec: Record) -> float:
	var base: Record = record(rec.variant_index, rec.game, BASELINE)
	if base == null or rec.heat_units == 0:
		return 0.0
	return (rec.ev_per_hand() - base.ev_per_hand()) / rec.heat_per_hand()


func merge(other: SimReport) -> void:
	for theirs: Record in other._records.values():
		var mine: Record = _records.get(theirs.key())
		if mine == null:
			mine = Record.new()
			mine.variant_index = theirs.variant_index
			mine.variant = theirs.variant
			mine.game = theirs.game
			mine.bot_index = theirs.bot_index
			mine.bot = theirs.bot
			_records[theirs.key()] = mine
		mine.sessions += theirs.sessions
		mine.hands += theirs.hands
		mine.net += theirs.net
		mine.staked += theirs.staked
		mine.heat_units += theirs.heat_units
		mine.backed_off += theirs.backed_off


func to_dict() -> Dictionary:
	var rows: Array = []
	for rec: Record in records():
		rows.append(
			[
				rec.variant_index, rec.variant, rec.game, rec.bot_index, rec.bot,
				rec.sessions, rec.hands, rec.net, rec.staked, rec.heat_units, rec.backed_off,
			]
		)
	return {"records": rows}


static func from_dict(saved: Dictionary) -> SimReport:
	var report: SimReport = SimReport.new()
	var rows: Array = saved["records"]
	for row: Array in rows:
		var rec: Record = Record.new()
		rec.variant_index = _int(row[0])
		rec.variant = str(row[1])
		rec.game = _int(row[2]) as GameKind.Kind
		rec.bot_index = _int(row[3])
		rec.bot = str(row[4])
		rec.sessions = _int(row[5])
		rec.hands = _int(row[6])
		rec.net = _int(row[7])
		rec.staked = _int(row[8])
		rec.heat_units = _int(row[9])
		rec.backed_off = _int(row[10])
		report._records[rec.key()] = rec
	return report


func format() -> String:
	var lines: PackedStringArray = []
	var variant: int = -1
	var header: String = "%-10s %-16s %8s %10s %8s %8s %9s %9s %6s" % [
		"game", "bot", "hands", "EV/hand", "edge", "heat/h", "$/heat", "marg $/h", "b.off"
	]
	for rec: Record in records():
		if rec.variant_index != variant:
			variant = rec.variant_index
			if not lines.is_empty():
				lines.append("")
			lines.append("== %s ==" % rec.variant)
			lines.append(header)
		lines.append(
			"%-10s %-16s %8d %10.1f %7.2f%% %8.2f %9.1f %9.1f %6d" % [
				_game_name(rec.game),
				rec.bot,
				rec.hands,
				rec.ev_per_hand(),
				rec.edge() * 100.0,
				rec.heat_per_hand(),
				rec.dollars_per_heat(),
				marginal_dollars_per_heat(rec),
				rec.backed_off,
			]
		)
	return "\n".join(lines)


static func _game_name(game: GameKind.Kind) -> String:
	var name: String = GameKind.Kind.keys()[game]
	return name.to_lower()


## JSON reads every number as a float.
static func _int(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return roundi(number)
	var whole: int = value
	return whole
