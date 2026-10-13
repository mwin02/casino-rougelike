extends GdUnitTestSuite
## Items in words (spec §9): every item has a name, a rarity, a build and an
## effect line, and an effect's numbers follow config.

var _config: TuneConfig = TuneConfig.load_default()


func test_every_item_has_its_words() -> void:
	for item: ItemKind.Kind in ItemKind.Kind.values():
		var info: ItemInfo = ItemInfo.of(item, _config)
		assert_str(info.name).is_equal(ItemKind.NAMES[item])
		assert_str(info.rarity_text).is_not_empty()
		assert_str(info.archetype).is_not_empty()
		assert_str(info.effect).is_not_empty()


func test_an_items_rarity_is_spelt_out() -> void:
	var info: ItemInfo = ItemInfo.of(ItemKind.Kind.PIT_LEDGER, _config)
	assert_int(info.rarity).is_equal(ItemKind.Rarity.UNCOMMON)
	assert_str(info.rarity_text).is_equal("UNCOMMON")
	assert_str(info.archetype).is_equal("READER · MARKER")


## The spec's §9 lines, at the default config.
func test_effects_read_as_the_spec_has_them(
	item: ItemKind.Kind,
	expected: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
	[ItemKind.Kind.SHADED_LENSES, "Unlocks full reveal"],
	[ItemKind.Kind.POKER_FACE, "First window each hand is free"],
	[
		ItemKind.Kind.LUMINOUS_INK,
		"+1 symbol; its marks add half as much to the heat floor",
	],
	[ItemKind.Kind.HOUSE_REGULAR, "Straight hands cool the table 50% more"],
	[ItemKind.Kind.COMPED_SUITE, "Standing up rolls over 6% instead of 10%"],
	[ItemKind.Kind.LOADED_QUESTION, "Partial reveals answer 2 questions"],
	[ItemKind.Kind.TELL_READER, "Marking costs 1 less at low-stakes tables"],
	[ItemKind.Kind.SLEIGHT, "Nudge costs 40% less"],
	[ItemKind.Kind.SIGNATURE, "Marked cards pay +25% when they land in your hand"],
	[ItemKind.Kind.FORGED_PAPERS, "Heat floor −10"],
	[ItemKind.Kind.HIGH_ROLLERS_NERVE, "Bets above the table midpoint pay +20%"],
	[ItemKind.Kind.SIDE_POCKET, "Side bet cap 50% of table max"],
	[ItemKind.Kind.LATE_NIGHT, "+5 hands on every floor"],
	[ItemKind.Kind.COMPED_BREAKFAST, "Up to 10 unused hands carry to the next floor"],
	[
		ItemKind.Kind.PERMANENT_INK,
		"2 charges a floor: a charge makes this hand's change permanent",
	],
]
) -> void:
	assert_str(ItemInfo.of(item, _config).effect).is_equal(expected)


func test_an_effects_number_follows_config() -> void:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	var changed: TuneConfig = TuneConfig.parse(
		text.replace("sleight_nudge_pct=60", "sleight_nudge_pct=75")
	)
	assert_str(ItemInfo.of(ItemKind.Kind.SLEIGHT, changed).effect).is_equal(
		"Nudge costs 25% less"
	)


func test_luminous_inks_share_of_the_floor_follows_config() -> void:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	var changed: TuneConfig = TuneConfig.parse(
		text.replace("floor_per_luminous_mark=0.5", "floor_per_luminous_mark=0.25")
	)
	assert_str(ItemInfo.of(ItemKind.Kind.LUMINOUS_INK, changed).effect).is_equal(
		"+1 symbol; its marks add 25% as much to the heat floor"
	)
