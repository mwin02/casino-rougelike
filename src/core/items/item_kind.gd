class_name ItemKind
extends RefCounted
## The 26 items (spec §9) and what each one is: its rarity, which prices it
## (§6.4), the action it unlocks, and the symbol it adds. What an item does
## lands in ActionKit, the one place items turn into effects.

enum Kind {
	# Unlocks and symbols
	SHADED_LENSES,
	MIRROR_RING,
	DYED_THUMB,
	MECHANICS_GRIP,
	COLD_DECK,
	WAX_PENCIL,
	GREASE_PENCIL,
	LUMINOUS_INK,
	# Heat
	POKER_FACE,
	HOUSE_REGULAR,
	COMPED_SUITE,
	QUIET_HANDS,
	# Information
	LOADED_QUESTION,
	DEEP_READ,
	PIT_LEDGER,
	TELL_READER,
	# Deck
	PERMANENT_INK,
	SLEIGHT,
	SECOND_DECK,
	SIGNATURE,
	FORGED_PAPERS,
	# Bets and clock
	HIGH_ROLLERS_NERVE,
	SIDE_POCKET,
	COMP_SLIP,
	LATE_NIGHT,
	COMPED_BREAKFAST,
}

enum Rarity { COMMON, UNCOMMON, RARE }

const RARITY: Dictionary[Kind, Rarity] = {
	Kind.SHADED_LENSES: Rarity.RARE,
	Kind.MIRROR_RING: Rarity.RARE,
	Kind.DYED_THUMB: Rarity.UNCOMMON,
	Kind.MECHANICS_GRIP: Rarity.RARE,
	Kind.COLD_DECK: Rarity.RARE,
	Kind.WAX_PENCIL: Rarity.UNCOMMON,
	Kind.GREASE_PENCIL: Rarity.UNCOMMON,
	Kind.LUMINOUS_INK: Rarity.RARE,
	Kind.POKER_FACE: Rarity.UNCOMMON,
	Kind.HOUSE_REGULAR: Rarity.COMMON,
	Kind.COMPED_SUITE: Rarity.UNCOMMON,
	Kind.QUIET_HANDS: Rarity.COMMON,
	Kind.LOADED_QUESTION: Rarity.UNCOMMON,
	Kind.DEEP_READ: Rarity.UNCOMMON,
	Kind.PIT_LEDGER: Rarity.UNCOMMON,
	Kind.TELL_READER: Rarity.COMMON,
	Kind.PERMANENT_INK: Rarity.RARE,
	Kind.SLEIGHT: Rarity.COMMON,
	Kind.SECOND_DECK: Rarity.UNCOMMON,
	Kind.SIGNATURE: Rarity.UNCOMMON,
	Kind.FORGED_PAPERS: Rarity.UNCOMMON,
	Kind.HIGH_ROLLERS_NERVE: Rarity.UNCOMMON,
	Kind.SIDE_POCKET: Rarity.UNCOMMON,
	Kind.COMP_SLIP: Rarity.COMMON,
	Kind.LATE_NIGHT: Rarity.RARE,
	Kind.COMPED_BREAKFAST: Rarity.UNCOMMON,
}

## The five action unlocks. Everything else in the kit starts unlocked (§2.4).
const UNLOCKS: Dictionary[Kind, ActionKind.Kind] = {
	Kind.SHADED_LENSES: ActionKind.Kind.FULL_REVEAL,
	Kind.MIRROR_RING: ActionKind.Kind.LOOK_AHEAD,
	Kind.DYED_THUMB: ActionKind.Kind.RECOLOUR,
	Kind.MECHANICS_GRIP: ActionKind.Kind.SWITCH,
	Kind.COLD_DECK: ActionKind.Kind.PALM,
}

## Each symbol item adds one symbol with a fixed id, after the starting
## kit's 0 and 1, so losing one symbol item never renumbers another's marks.
const SYMBOLS: Dictionary[Kind, int] = {
	Kind.WAX_PENCIL: 2,
	Kind.GREASE_PENCIL: 3,
	Kind.LUMINOUS_INK: 4,
}

const NAMES: Dictionary[Kind, String] = {
	Kind.SHADED_LENSES: "Shaded Lenses",
	Kind.MIRROR_RING: "Mirror Ring",
	Kind.DYED_THUMB: "Dyed Thumb",
	Kind.MECHANICS_GRIP: "Mechanic's Grip",
	Kind.COLD_DECK: "Cold Deck",
	Kind.WAX_PENCIL: "Wax Pencil",
	Kind.GREASE_PENCIL: "Grease Pencil",
	Kind.LUMINOUS_INK: "Luminous Ink",
	Kind.POKER_FACE: "Poker Face",
	Kind.HOUSE_REGULAR: "House Regular",
	Kind.COMPED_SUITE: "Comped Suite",
	Kind.QUIET_HANDS: "Quiet Hands",
	Kind.LOADED_QUESTION: "Loaded Question",
	Kind.DEEP_READ: "Deep Read",
	Kind.PIT_LEDGER: "Pit Ledger",
	Kind.TELL_READER: "Tell Reader",
	Kind.PERMANENT_INK: "Permanent Ink",
	Kind.SLEIGHT: "Sleight",
	Kind.SECOND_DECK: "Second Deck",
	Kind.SIGNATURE: "Signature",
	Kind.FORGED_PAPERS: "Forged Papers",
	Kind.HIGH_ROLLERS_NERVE: "High Roller's Nerve",
	Kind.SIDE_POCKET: "Side Pocket",
	Kind.COMP_SLIP: "Comp Slip",
	Kind.LATE_NIGHT: "Late Night",
	Kind.COMPED_BREAKFAST: "Comped Breakfast",
}
