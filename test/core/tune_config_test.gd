extends GdUnitTestSuite
## The config file loads, and the blackjack rules read from it. Values pinned
## here are the spec §3.1 house rules.


func test_blackjack_rules_load_from_config() -> void:
	var rules: BlackjackRules = BlackjackRules.from_config(TuneConfig.load_default())
	assert_int(rules.bust_threshold).is_equal(23)
	assert_int(rules.natural_payout_num).is_equal(3)
	assert_int(rules.natural_payout_den).is_equal(2)
	assert_int(rules.dealer_stand).is_equal(17)
	assert_bool(rules.dealer_hits_soft_17).is_true()


func test_debug_bet_loads() -> void:
	assert_int(TuneConfig.load_default().get_int("debug", "debug_bet")).is_equal(1000)
