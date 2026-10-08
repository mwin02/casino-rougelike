class_name RunHeat
extends RefCounted
## Run heat thresholds (spec §7.4): the pit boss appears, the security sweep
## comes, and the player is ejected. The pit boss watches one table from his
## threshold and one more at each of more_tables_at (§7.5).

var pit_boss_at: float
var sweep_at: float
var eject_at: float
## Run heat where the pit boss watches one more table each.
var more_tables_at: Array[float] = []


static func from_config(config: TuneConfig) -> RunHeat:
	var rules: RunHeat = RunHeat.new()
	var thresholds: Array[float] = config.get_float_list("run_heat", "thresholds")
	rules.pit_boss_at = thresholds[0]
	rules.sweep_at = thresholds[1]
	rules.eject_at = thresholds[2]
	rules.more_tables_at = config.get_float_list("pit_boss", "more_tables_at")
	return rules


## Tables the pit boss watches on a floor at this run heat.
func watched_tables(run_heat: float) -> int:
	if run_heat < pit_boss_at:
		return 0
	var count: int = 1
	for at: float in more_tables_at:
		if run_heat >= at:
			count += 1
	return count


func ejects(run_heat: float) -> bool:
	return run_heat >= eject_at
