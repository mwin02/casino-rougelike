class_name GameKind
extends RefCounted
## The three table games (spec §3).

enum Kind { BLACKJACK, BACCARAT, HIGH_LOW }


## The game's section in config/tune.cfg.
static func config_section(game: Kind) -> String:
	var name: String = Kind.keys()[game]
	return name.to_lower()
