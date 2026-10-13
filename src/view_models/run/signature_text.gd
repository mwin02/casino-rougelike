class_name SignatureText
extends RefCounted
## A floor signature (spec §5.3) in words: its name, and its pressure in a
## plain line for the elevator.

const NAMES: Dictionary[FloorSignature.Kind, String] = {
	FloorSignature.Kind.BASELINE: "Baseline",
	FloorSignature.Kind.WATCHFUL_PIT: "Watchful pit",
	FloorSignature.Kind.STINGY_HOUSE: "Stingy house",
	FloorSignature.Kind.SHORT_NIGHTS: "Short nights",
	FloorSignature.Kind.BOSS: "Boss floor",
}
const PLAIN: Dictionary[FloorSignature.Kind, String] = {
	FloorSignature.Kind.BASELINE: "No pressure: the house plays it straight.",
	FloorSignature.Kind.WATCHFUL_PIT: "The pit is on edge: every action runs hotter here.",
	FloorSignature.Kind.STINGY_HOUSE: "The house pays short: main-game wins pay less.",
	FloorSignature.Kind.SHORT_NIGHTS: "Last call comes early: a smaller hand clock.",
	FloorSignature.Kind.BOSS: "The top floor.",
}


static func name_of(kind: FloorSignature.Kind) -> String:
	return NAMES[kind]


static func plain(kind: FloorSignature.Kind) -> String:
	return PLAIN[kind]
