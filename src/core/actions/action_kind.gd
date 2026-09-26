class_name ActionKind
extends RefCounted
## The eight window actions (spec §2.3).

enum Kind { PARTIAL_REVEAL, MARK, FULL_REVEAL, LOOK_AHEAD, RECOLOUR, NUDGE, SWITCH, PALM }

const KNOWLEDGE: Array[Kind] = [Kind.PARTIAL_REVEAL, Kind.MARK, Kind.FULL_REVEAL, Kind.LOOK_AHEAD]
## Any of these locks the bet for the rest of the hand (spec §2.2).
const MANIPULATION: Array[Kind] = [Kind.RECOLOUR, Kind.NUDGE, Kind.SWITCH, Kind.PALM]
