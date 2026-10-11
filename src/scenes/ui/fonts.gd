class_name Fonts
extends RefCounted
## The table screen's typefaces, from the design canvas: Fredoka for titles
## and buttons, Nunito for body text, Barlow Condensed for labels and
## numbers, DM Serif Display on the cards, Space Mono on the camera view.

enum Face { TITLE, BUTTON, BODY, BODY_HEAVY, LABEL, NUMBER, CARD, CAMERA }

const DIR: String = "res://assets/fonts/"
## Each face's file, and its weight where the file is a variable font.
const FILES: Dictionary[Face, String] = {
	Face.TITLE: "Fredoka.ttf",
	Face.BUTTON: "Fredoka.ttf",
	Face.BODY: "Nunito.ttf",
	Face.BODY_HEAVY: "Nunito.ttf",
	Face.LABEL: "BarlowCondensed-SemiBold.ttf",
	Face.NUMBER: "BarlowCondensed-Bold.ttf",
	Face.CARD: "DMSerifDisplay-Regular.ttf",
	Face.CAMERA: "SpaceMono-Bold.ttf",
}
const WEIGHTS: Dictionary[Face, int] = {
	Face.TITLE: 700,
	Face.BUTTON: 600,
	Face.BODY: 700,
	Face.BODY_HEAVY: 800,
}

static var _cache: Dictionary[Face, Font] = {}


static func of(face: Face) -> Font:
	if not _cache.has(face):
		_cache[face] = _load(face)
	return _cache[face]


static func _load(face: Face) -> Font:
	var file: FontFile = load(DIR + FILES[face])
	if not WEIGHTS.has(face):
		return file
	var font: FontVariation = FontVariation.new()
	font.base_font = file
	var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {weight: WEIGHTS[face]}
	return font
