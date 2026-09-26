class_name DeckRules
extends RefCounted
## Deck [TUNE] values (spec §4.1, §2.3).

const SECTION: String = "deck"
const DURATION_NAMES: Dictionary[String, ManipulationLayer.Duration] = {
	"hand": ManipulationLayer.Duration.HAND,
	"session": ManipulationLayer.Duration.SESSION,
}

## Removals stop at this many cards.
var min_size: int
## How long Nudge, Recolour and Switch last. Palm always lasts the session.
var manipulation_duration: ManipulationLayer.Duration


static func from_config(config: TuneConfig) -> DeckRules:
	var rules: DeckRules = DeckRules.new()
	rules.min_size = config.get_int(SECTION, "min_size")
	rules.manipulation_duration = parse_duration(config.get_string(SECTION, "manipulation_duration"))
	return rules


static func parse_duration(duration_name: String) -> ManipulationLayer.Duration:
	if not DURATION_NAMES.has(duration_name):
		push_error("DeckRules: manipulation_duration must be one of %s" % [DURATION_NAMES.keys()])
		return ManipulationLayer.Duration.SESSION
	return DURATION_NAMES[duration_name]


func duration_for(is_palm: bool) -> ManipulationLayer.Duration:
	return ManipulationLayer.Duration.SESSION if is_palm else manipulation_duration
