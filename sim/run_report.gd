class_name RunReport
extends RefCounted
## Whole runs (spec §7.4, §11, §12): per config variant and bot, how often a
## run wins, is ejected or is lost short or broke, ejections by the end of floor 2 and before floor
## 4 (the run heat targets), the floor reached, and dollars per heat. Counts
## merge exactly across shards.


class Record:
	var variant_index: int
	var variant: String
	var bot_index: int
	var bot: String
	var runs: int = 0
	var won: int = 0
	var ejected: int = 0
	## Ejected on floor 1 or 2 (§12: reckless).
	var ejected_by_floor_2: int = 0
	## Ejected on floors 1–3 (§12: normal).
	var ejected_before_floor_4: int = 0
	## Lost short at a quota check, or broke at a table (§11).
	var lost_short: int = 0
	var lost_broke: int = 0
	## Reached floor 2 (passed floor 1) and floor 3 (§12: viability).
	var reached_floor_2: int = 0
	var reached_floor_3: int = 0
	var floors_reached: int = 0
	var dollars_per_heat: float = 0.0

	func rate(count: int) -> float:
		return float(count) / runs if runs > 0 else 0.0

	func mean_floor() -> float:
		return float(floors_reached) / runs if runs > 0 else 0.0

	func mean_dollars_per_heat() -> float:
		return dollars_per_heat / runs if runs > 0 else 0.0


var _records: Dictionary[String, Record] = {}


func add(
	variant_index: int, variant: String, bot_index: int, bot: String, result: RunResult
) -> void:
	var record: Record = _record(variant_index, variant, bot_index, bot)
	record.runs += 1
	record.won += int(result.won)
	record.ejected += int(result.ejected)
	record.ejected_by_floor_2 += int(result.ejected and result.floor_reached <= 2)
	record.ejected_before_floor_4 += int(result.ejected and result.floor_reached < 4)
	record.lost_short += int(result.end == RunResult.End.SHORT)
	record.lost_broke += int(result.end == RunResult.End.BROKE)
	record.reached_floor_2 += int(result.floor_reached >= 2)
	record.reached_floor_3 += int(result.floor_reached >= 3)
	record.floors_reached += result.floor_reached
	record.dollars_per_heat += result.dollars_per_heat


## Every record: variant, then bot, in run order.
func records() -> Array[Record]:
	var result: Array[Record] = []
	result.assign(_records.values())
	result.sort_custom(
		func(a: Record, b: Record) -> bool:
			if a.variant_index != b.variant_index:
				return a.variant_index < b.variant_index
			return a.bot_index < b.bot_index
	)
	return result


func merge(other: RunReport) -> void:
	for theirs: Record in other.records():
		var mine: Record = _record(
			theirs.variant_index, theirs.variant, theirs.bot_index, theirs.bot
		)
		mine.runs += theirs.runs
		mine.won += theirs.won
		mine.ejected += theirs.ejected
		mine.ejected_by_floor_2 += theirs.ejected_by_floor_2
		mine.ejected_before_floor_4 += theirs.ejected_before_floor_4
		mine.lost_short += theirs.lost_short
		mine.lost_broke += theirs.lost_broke
		mine.reached_floor_2 += theirs.reached_floor_2
		mine.reached_floor_3 += theirs.reached_floor_3
		mine.floors_reached += theirs.floors_reached
		mine.dollars_per_heat += theirs.dollars_per_heat


func to_dict() -> Dictionary:
	var rows: Array = []
	for rec: Record in records():
		rows.append(
			[
				rec.variant_index, rec.variant, rec.bot_index, rec.bot, rec.runs, rec.won,
				rec.ejected, rec.ejected_by_floor_2, rec.ejected_before_floor_4,
				rec.floors_reached, rec.dollars_per_heat, rec.lost_short, rec.lost_broke,
				rec.reached_floor_2, rec.reached_floor_3,
			]
		)
	return {"kind": "run", "records": rows}


static func from_dict(saved: Dictionary) -> RunReport:
	var report: RunReport = RunReport.new()
	var rows: Array = saved["records"]
	for row: Array in rows:
		var rec: Record = report._record(
			SimReport._int(row[0]), str(row[1]), SimReport._int(row[2]), str(row[3])
		)
		rec.runs = SimReport._int(row[4])
		rec.won = SimReport._int(row[5])
		rec.ejected = SimReport._int(row[6])
		rec.ejected_by_floor_2 = SimReport._int(row[7])
		rec.ejected_before_floor_4 = SimReport._int(row[8])
		rec.floors_reached = SimReport._int(row[9])
		var dph: float = row[10]
		rec.dollars_per_heat = dph
		rec.lost_short = SimReport._int(row[11])
		rec.lost_broke = SimReport._int(row[12])
		rec.reached_floor_2 = SimReport._int(row[13])
		rec.reached_floor_3 = SimReport._int(row[14])
	return report


func format() -> String:
	var lines: PackedStringArray = []
	var variant: int = -1
	var header: String = "%-16s %6s %7s %7s %7s %8s %9s %9s %7s %7s %7s %9s" % [
		"bot", "runs", "won", "F2+", "F3+", "ejected", "ej by F2", "ej < F4", "short", "broke",
		"floor", "$/heat"
	]
	for rec: Record in records():
		if rec.variant_index != variant:
			variant = rec.variant_index
			if not lines.is_empty():
				lines.append("")
			lines.append("== %s ==" % rec.variant)
			lines.append(header)
		lines.append(
			"%-16s %6d %6.1f%% %6.1f%% %6.1f%% %7.1f%% %8.1f%% %8.1f%% %6.1f%% %6.1f%% %7.2f %9.0f" % [
				rec.bot,
				rec.runs,
				rec.rate(rec.won) * 100.0,
				rec.rate(rec.reached_floor_2) * 100.0,
				rec.rate(rec.reached_floor_3) * 100.0,
				rec.rate(rec.ejected) * 100.0,
				rec.rate(rec.ejected_by_floor_2) * 100.0,
				rec.rate(rec.ejected_before_floor_4) * 100.0,
				rec.rate(rec.lost_short) * 100.0,
				rec.rate(rec.lost_broke) * 100.0,
				rec.mean_floor(),
				rec.mean_dollars_per_heat(),
			]
		)
	return "\n".join(lines)


func _record(variant_index: int, variant: String, bot_index: int, bot: String) -> Record:
	var key: String = "%d|%s" % [variant_index, bot]
	if not _records.has(key):
		var fresh: Record = Record.new()
		fresh.variant_index = variant_index
		fresh.variant = variant
		fresh.bot_index = bot_index
		fresh.bot = bot
		_records[key] = fresh
	return _records[key]
