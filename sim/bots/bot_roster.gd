class_name BotRoster
extends RefCounted
## Every bot the harness knows, by name. Each build makes fresh bots.


static func names() -> Array[String]:
	var result: Array[String] = []
	for bot: Bot in _all():
		result.append(bot.bot_name())
	return result


## Fresh bots for names, in that order. Unknown names are left out.
static func build(bot_names: Array[String]) -> Array[Bot]:
	var result: Array[Bot] = []
	for name: String in bot_names:
		for bot: Bot in _all():
			if bot.bot_name() == name:
				result.append(bot)
	return result


static func _all() -> Array[Bot]:
	return [
		StraightFlatBot.new(),
		BoldBot.new(),
		HonestAdjusterBot.new(),
		RevealBot.new("reveal_only", false),
		RevealBot.new("reveal_adjust", true),
		HighLowGreedyBot.new(),
		ManipulateMaxBot.new(),
	]
