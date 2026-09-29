class_name SimRun
extends RefCounted
## Runs a shard of the harness in this process. Session i of every variant,
## game and bot plays on seed + i, so every bot meets the same shuffles and
## the report never depends on how sessions are split across processes.


## Null with the problems printed when the options or overrides are bad.
static func dollars_per_heat(options: SimOptions) -> SimReport:
	var variants: Array[SimVariant] = variants_of(options)
	var names: Array[String] = bot_names(options)
	if variants.is_empty() or names.is_empty():
		return null
	var report: SimReport = SimReport.new()
	for variant_index: int in variants.size():
		var variant: SimVariant = variants[variant_index]
		for game: GameKind.Kind in options.games:
			for bot_index: int in names.size():
				if not BotRoster.build([names[bot_index]])[0].plays(game):
					continue
				for index: int in options.shard_sessions():
					var bot: Bot = BotRoster.build([names[bot_index]])[0]
					var result: SessionResult = SessionRunner.run(
						variant.config,
						bot,
						game,
						options.stakes,
						options.floor_number,
						options.hands,
						options.seed + index
					)
					report.add(variant_index, variant.label, game, bot_index, bot.bot_name(), result)
	return report


## The config variants, or none with the problems printed.
static func variants_of(options: SimOptions) -> Array[SimVariant]:
	var config: SimConfig = SimConfig.from_default()
	for spec: String in options.sets:
		config.add_override(spec)
	var variants: Array[SimVariant] = config.variants()
	var problems: PackedStringArray = options.problems.duplicate()
	problems.append_array(config.problems())
	for problem: String in problems:
		printerr("sim: ", problem)
	return variants if problems.is_empty() else ([] as Array[SimVariant])


## The bots to run, straight_flat first as the baseline. None, with the
## problem printed, when a name is unknown.
static func bot_names(options: SimOptions) -> Array[String]:
	var known: Array[String] = BotRoster.names()
	var names: Array[String] = [SimReport.BASELINE]
	for name: String in options.bots if not options.bots.is_empty() else known:
		if name not in known:
			printerr("sim: unknown bot %s (known: %s)" % [name, ", ".join(known)])
			return []
		if name not in names:
			names.append(name)
	return names
