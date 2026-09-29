class_name FloorReport
extends RefCounted
## Quota clearance (spec §12): per config variant, game and bot, how often a
## floor clears, the hands it takes, and the run heat it leaves, with run
## heat's spread kept as a whole-point histogram so shards merge exactly.

## Run heat at or past this lands in the last bucket (ejected, §7.4).
const HEAT_BUCKETS: int = 101


class Record:
	var variant_index: int
	var variant: String
	var game: GameKind.Kind
	var bot_index: int
	var bot: String
	var floors: int = 0
	var cleared: int = 0
	var hands: int = 0
	## floors ending with run heat in [i, i + 1), the last bucket open.
	var heat_counts: Array[int] = []

	func _init() -> void:
		heat_counts.resize(HEAT_BUCKETS)
		heat_counts.fill(0)

	func clear_rate() -> float:
		return float(cleared) / floors if floors > 0 else 0.0

	func mean_hands() -> float:
		return float(hands) / floors if floors > 0 else 0.0

	## From the buckets: each floor counts at its bucket's lower bound.
	func mean_run_heat() -> float:
		var total: int = 0
		for bucket: int in HEAT_BUCKETS:
			total += bucket * heat_counts[bucket]
		return float(total) / floors if floors > 0 else 0.0

	## The smallest whole run heat at least share of floors end at or below.
	func run_heat_percentile(share: float) -> int:
		var seen: int = 0
		for bucket: int in HEAT_BUCKETS:
			seen += heat_counts[bucket]
			if seen >= share * floors:
				return bucket
		return HEAT_BUCKETS - 1


var _records: Dictionary[String, Record] = {}


func add(
	variant_index: int,
	variant: String,
	game: GameKind.Kind,
	bot_index: int,
	bot: String,
	result: FloorResult
) -> void:
	var record: Record = _record(variant_index, variant, game, bot_index, bot)
	record.floors += 1
	record.cleared += int(result.cleared)
	record.hands += result.hands
	record.heat_counts[clampi(floori(result.run_heat), 0, HEAT_BUCKETS - 1)] += 1


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


func merge(other: FloorReport) -> void:
	for theirs: Record in other.records():
		var mine: Record = _record(
			theirs.variant_index, theirs.variant, theirs.game, theirs.bot_index, theirs.bot
		)
		mine.floors += theirs.floors
		mine.cleared += theirs.cleared
		mine.hands += theirs.hands
		for bucket: int in HEAT_BUCKETS:
			mine.heat_counts[bucket] += theirs.heat_counts[bucket]


func to_dict() -> Dictionary:
	var rows: Array = []
	for rec: Record in records():
		rows.append(
			[
				rec.variant_index, rec.variant, rec.game, rec.bot_index, rec.bot,
				rec.floors, rec.cleared, rec.hands, rec.heat_counts,
			]
		)
	return {"kind": "floor", "records": rows}


static func from_dict(saved: Dictionary) -> FloorReport:
	var report: FloorReport = FloorReport.new()
	var rows: Array = saved["records"]
	for row: Array in rows:
		var rec: Record = report._record(
			SimReport._int(row[0]),
			str(row[1]),
			SimReport._int(row[2]) as GameKind.Kind,
			SimReport._int(row[3]),
			str(row[4])
		)
		rec.floors = SimReport._int(row[5])
		rec.cleared = SimReport._int(row[6])
		rec.hands = SimReport._int(row[7])
		var counts: Array = row[8]
		for bucket: int in HEAT_BUCKETS:
			rec.heat_counts[bucket] = SimReport._int(counts[bucket])
	return report


func format() -> String:
	var lines: PackedStringArray = []
	var variant: int = -1
	var header: String = "%-10s %-16s %7s %8s %8s %9s %8s" % [
		"game", "bot", "floors", "cleared", "hands", "run heat", "p90 heat"
	]
	for rec: Record in records():
		if rec.variant_index != variant:
			variant = rec.variant_index
			if not lines.is_empty():
				lines.append("")
			lines.append("== %s ==" % rec.variant)
			lines.append(header)
		lines.append(
			"%-10s %-16s %7d %7.1f%% %8.1f %9.1f %8d" % [
				SimReport._game_name(rec.game),
				rec.bot,
				rec.floors,
				rec.clear_rate() * 100.0,
				rec.mean_hands(),
				rec.mean_run_heat(),
				rec.run_heat_percentile(0.9),
			]
		)
	return "\n".join(lines)


func _record(
	variant_index: int, variant: String, game: GameKind.Kind, bot_index: int, bot: String
) -> Record:
	var key: String = SimReport.key_of(variant_index, game, bot)
	if not _records.has(key):
		var fresh: Record = Record.new()
		fresh.variant_index = variant_index
		fresh.variant = variant
		fresh.game = game
		fresh.bot_index = bot_index
		fresh.bot = bot
		_records[key] = fresh
	return _records[key]
