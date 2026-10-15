class_name ItemInfo
extends RefCounted
## One item as the shop and the kit screen show it (spec §9): its name,
## rarity, the builds it suits, and its effect in a line. Every number in an
## effect is read from config.

const RARITY_NAMES: Dictionary[ItemKind.Rarity, String] = {
	ItemKind.Rarity.COMMON: "COMMON",
	ItemKind.Rarity.UNCOMMON: "UNCOMMON",
	ItemKind.Rarity.RARE: "RARE",
}
const ARCHETYPES: Dictionary[ItemKind.Kind, String] = {
	ItemKind.Kind.SHADED_LENSES: "READER",
	ItemKind.Kind.MIRROR_RING: "READER",
	ItemKind.Kind.DYED_THUMB: "MECHANIC",
	ItemKind.Kind.MECHANICS_GRIP: "MECHANIC",
	ItemKind.Kind.COLD_DECK: "MECHANIC",
	ItemKind.Kind.WAX_PENCIL: "MARKER",
	ItemKind.Kind.GREASE_PENCIL: "MARKER",
	ItemKind.Kind.LUMINOUS_INK: "MARKER",
	ItemKind.Kind.POKER_FACE: "READER",
	ItemKind.Kind.HOUSE_REGULAR: "MECHANIC",
	ItemKind.Kind.COMPED_SUITE: "ANY",
	ItemKind.Kind.QUIET_HANDS: "READER",
	ItemKind.Kind.LOADED_QUESTION: "READER",
	ItemKind.Kind.DEEP_READ: "READER",
	ItemKind.Kind.PIT_LEDGER: "READER · MARKER",
	ItemKind.Kind.TELL_READER: "MARKER",
	ItemKind.Kind.PERMANENT_INK: "MECHANIC · STACKER",
	ItemKind.Kind.SLEIGHT: "MECHANIC",
	ItemKind.Kind.SECOND_DECK: "STACKER",
	ItemKind.Kind.SIGNATURE: "MARKER",
	ItemKind.Kind.FORGED_PAPERS: "STACKER · MARKER",
	ItemKind.Kind.HIGH_ROLLERS_NERVE: "WHALE",
	ItemKind.Kind.SIDE_POCKET: "STACKER",
	ItemKind.Kind.COMP_SLIP: "WHALE",
	ItemKind.Kind.LATE_NIGHT: "ANY",
	ItemKind.Kind.COMPED_BREAKFAST: "READER",
}
## Effects with no number in them.
const PLAIN: Dictionary[ItemKind.Kind, String] = {
	ItemKind.Kind.SHADED_LENSES: "Unlocks full reveal",
	ItemKind.Kind.MIRROR_RING: "Unlocks look ahead",
	ItemKind.Kind.DYED_THUMB: "Unlocks Recolour",
	ItemKind.Kind.MECHANICS_GRIP: "Unlocks Switch",
	ItemKind.Kind.COLD_DECK: "Unlocks Palm",
	ItemKind.Kind.WAX_PENCIL: "+1 symbol",
	ItemKind.Kind.GREASE_PENCIL: "+1 symbol",
	ItemKind.Kind.POKER_FACE: "First window each hand is free",
	ItemKind.Kind.QUIET_HANDS: "Lowering your bet adds no bet-size heat",
	ItemKind.Kind.DEEP_READ: "Later windows cost the same as the first",
	ItemKind.Kind.PIT_LEDGER: (
		"On sitting down, reveals the table's cost rolls and its Marked consequence"
	),
	ItemKind.Kind.SECOND_DECK: "Card removals cost a flat price, no escalation",
	ItemKind.Kind.COMP_SLIP: "First stake each session refunded if lost",
}

var kind: ItemKind.Kind
var name: String
var rarity: ItemKind.Rarity
## "UNCOMMON".
var rarity_text: String
## "READER · MARKER".
var archetype: String
var effect: String


static func of(item: ItemKind.Kind, config: TuneConfig) -> ItemInfo:
	var info: ItemInfo = ItemInfo.new()
	info.kind = item
	info.name = ItemKind.NAMES[item]
	info.rarity = ItemKind.RARITY[item]
	info.rarity_text = RARITY_NAMES[info.rarity]
	info.archetype = ARCHETYPES[item]
	info.effect = PLAIN[item] if PLAIN.has(item) else _numbered(item, config)
	return info


## The effects that quote a [TUNE] value.
static func _numbered(item: ItemKind.Kind, config: TuneConfig) -> String:
	var rules: ItemRules = ItemRules.from_config(config)
	match item:
		ItemKind.Kind.LUMINOUS_INK:
			var deck: DeckRules = DeckRules.from_config(config)
			var share: int = roundi(deck.floor_per_luminous_mark / deck.floor_per_mark * 100.0)
			var much: String = "half" if share == 50 else "%d%%" % share
			return "+1 symbol; its marks add %s as much to the heat floor" % much
		ItemKind.Kind.HOUSE_REGULAR:
			var usual: float = config.get_float("cooling", "cool_rate")
			var more: int = roundi((rules.house_regular_cool_rate / usual - 1.0) * 100.0)
			return "Straight hands cool the table %d%% more" % more
		ItemKind.Kind.COMPED_SUITE:
			var usual: int = roundi(config.get_float("run_heat", "stand_up_rollover") * 100.0)
			var share: int = roundi(rules.comped_suite_rollover * 100.0)
			return "Standing up rolls over %d%% instead of %d%%" % [share, usual]
		ItemKind.Kind.LOADED_QUESTION:
			return "Partial reveals answer %d questions" % rules.loaded_question_questions
		ItemKind.Kind.TELL_READER:
			return "Marking costs %s less at low-stakes tables" % _plain(rules.tell_reader_mark_cut)
		ItemKind.Kind.PERMANENT_INK:
			return (
				"%d charges a floor: a charge makes this hand's change permanent"
				% rules.ink_charges_per_floor
			)
		ItemKind.Kind.SLEIGHT:
			return "Nudge costs %d%% less" % (100 - rules.sleight_nudge_pct)
		ItemKind.Kind.SIGNATURE:
			return "Marked cards pay +%d%% when they land in your hand" % rules.signature_bonus_pct
		ItemKind.Kind.FORGED_PAPERS:
			var cut: float = DeckRules.from_config(config).forged_papers_floor_cut
			return "Heat floor −%s" % _plain(cut)
		ItemKind.Kind.HIGH_ROLLERS_NERVE:
			return "Bets above the table midpoint pay +%d%%" % rules.high_roller_bonus_pct
		ItemKind.Kind.SIDE_POCKET:
			return "Side bet cap %d%% of table max" % rules.side_pocket_cap_pct
		ItemKind.Kind.LATE_NIGHT:
			return "+%d hands on every floor" % rules.late_night_hands
		ItemKind.Kind.COMPED_BREAKFAST:
			return "Up to %d unused hands carry to the next floor" % rules.breakfast_carry_max
	return ""


## "1" for 1.0, "1.5" for 1.5.
static func _plain(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)
