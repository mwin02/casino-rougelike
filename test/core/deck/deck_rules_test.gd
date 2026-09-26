extends GdUnitTestSuite
## Deck rules load from config (spec §4.1).


func test_min_size_loads() -> void:
	# Spec §4.1: minimum deck size 20.
	assert_int(DeckRules.from_config(TuneConfig.load_default()).min_size).is_equal(20)
