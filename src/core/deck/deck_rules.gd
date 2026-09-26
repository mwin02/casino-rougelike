class_name DeckRules
extends RefCounted
## Deck [TUNE] values (spec §4.1).

const SECTION: String = "deck"

## Removals stop at this many cards.
var min_size: int


static func from_config(config: TuneConfig) -> DeckRules:
	var rules: DeckRules = DeckRules.new()
	rules.min_size = config.get_int(SECTION, "min_size")
	return rules
