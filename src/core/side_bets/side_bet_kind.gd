class_name SideBetKind
extends RefCounted
## The six side bets (spec §8) and the game each belongs to.

enum Kind { PERFECT_PAIRS, TWENTY_ONE_PLUS_THREE, BUST_IT, DRAGON_BONUS, PAIR, EXACT_RANK }


static func game_of(kind: Kind) -> GameKind.Kind:
	match kind:
		Kind.DRAGON_BONUS, Kind.PAIR:
			return GameKind.Kind.BACCARAT
		Kind.EXACT_RANK:
			return GameKind.Kind.HIGH_LOW
	return GameKind.Kind.BLACKJACK


## The side bets offered at this game's stake window.
static func for_game(game: GameKind.Kind) -> Array[Kind]:
	var kinds: Array[Kind] = []
	for kind: Kind in Kind.values():
		if game_of(kind) == game:
			kinds.append(kind)
	return kinds
