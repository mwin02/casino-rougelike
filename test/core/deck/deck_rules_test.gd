extends GdUnitTestSuite
## Deck rules load from config (spec §4.1, §2.3).


func test_min_size_loads() -> void:
	# Spec §4.1: minimum deck size 20.
	assert_int(DeckRules.from_config(TuneConfig.load_default()).min_size).is_equal(20)


func test_manipulation_duration_defaults_to_session() -> void:
	# Spec §2.3: manipulation lasts the table session.
	var rules: DeckRules = DeckRules.from_config(TuneConfig.load_default())
	assert_int(rules.manipulation_duration).is_equal(ManipulationLayer.Duration.SESSION)


func test_hand_mode_applies_to_everything_but_palm() -> void:
	var rules: DeckRules = DeckRules.new()
	rules.manipulation_duration = ManipulationLayer.Duration.HAND
	assert_int(rules.duration_for(false)).is_equal(ManipulationLayer.Duration.HAND)
	assert_int(rules.duration_for(true)).is_equal(ManipulationLayer.Duration.SESSION)


func test_duration_names_parse() -> void:
	assert_int(DeckRules.parse_duration("hand")).is_equal(ManipulationLayer.Duration.HAND)
	assert_int(DeckRules.parse_duration("session")).is_equal(ManipulationLayer.Duration.SESSION)
