extends GdUnitTestSuite
## The harness runs the default config with `--set section.key=value`
## overrides; a comma list sweeps one key over several values.


func _config(sets: Array[String]) -> SimConfig:
	var config: SimConfig = SimConfig.from_default()
	for spec: String in sets:
		config.add_override(spec)
	return config


func test_no_overrides_is_one_default_variant() -> void:
	var variants: Array[SimVariant] = _config([]).variants()
	assert_int(variants.size()).is_equal(1)
	assert_str(variants[0].label).is_equal("default")
	assert_float(variants[0].config.get_float("blackjack", "bet_change_base")).is_equal(
		TuneConfig.load_default().get_float("blackjack", "bet_change_base")
	)


func test_an_override_changes_the_value() -> void:
	var variants: Array[SimVariant] = _config(["blackjack.bet_change_base=4.5"]).variants()
	assert_int(variants.size()).is_equal(1)
	assert_float(variants[0].config.get_float("blackjack", "bet_change_base")).is_equal(4.5)
	assert_str(variants[0].label).is_equal("blackjack.bet_change_base=4.5")


func test_an_int_is_read_as_a_float_for_a_float_key() -> void:
	var config: SimConfig = _config(["blackjack.bet_change_base=4"])
	assert_array(config.problems()).is_empty()
	assert_float(config.variants()[0].config.get_float("blackjack", "bet_change_base")).is_equal(4.0)


func test_a_list_value_keeps_its_commas() -> void:
	var config: SimConfig = _config(["high_low.cut_pct=5", "heat.multiplier_values=[1, 2, 3]"])
	assert_array(config.problems()).is_empty()
	var variants: Array[SimVariant] = config.variants()
	assert_int(variants.size()).is_equal(1)
	assert_array(variants[0].config.get_float_list("heat", "multiplier_values")).contains_exactly(
		[1.0, 2.0, 3.0]
	)


func test_a_comma_list_sweeps_the_key() -> void:
	var variants: Array[SimVariant] = _config(["blackjack.bet_change_base=0,1,4"]).variants()
	var bases: Array[float] = []
	for variant: SimVariant in variants:
		bases.append(variant.config.get_float("blackjack", "bet_change_base"))
	assert_array(bases).contains_exactly([0.0, 1.0, 4.0])


func test_two_sweeps_multiply() -> void:
	var variants: Array[SimVariant] = _config(
		["blackjack.bet_change_base=0,4", "high_low.cut_pct=5,7,9"]
	).variants()
	assert_int(variants.size()).is_equal(6)
	assert_str(variants[0].label).is_equal("blackjack.bet_change_base=0.0 high_low.cut_pct=5")
	assert_str(variants[5].label).is_equal("blackjack.bet_change_base=4.0 high_low.cut_pct=9")


func test_an_unknown_key_is_a_problem() -> void:
	var config: SimConfig = _config(["heat.no_such_key=1"])
	assert_bool(config.problems().size() > 0).is_true()
	assert_str(config.problems()[0]).contains("heat.no_such_key")


func test_a_malformed_override_is_a_problem() -> void:
	assert_bool(_config(["bet_change_base=2"]).problems().size() > 0).is_true()
	assert_bool(_config(["blackjack.bet_change_base"]).problems().size() > 0).is_true()


func test_a_wrong_type_is_a_problem() -> void:
	var config: SimConfig = _config(["high_low.cut_pct=7.5"])
	assert_bool(config.problems().size() > 0).is_true()
