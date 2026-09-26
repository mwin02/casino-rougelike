extends GdUnitTestSuite
## config/tune.cfg holds every [TUNE] value and is checked against TuneSchema.
## Values pinned here are spec numbers, cited by section.


func _default_text() -> String:
	return FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)


## The default file with one line swapped out.
func _with_line(old: String, new: String) -> TuneConfig:
	var text: String = _default_text()
	assert_bool(text.contains(old)).is_true()
	return TuneConfig.parse(text.replace(old, new))


func _has_problem(config: TuneConfig, fragment: String) -> bool:
	for problem: String in config.problems():
		if problem.contains(fragment):
			return true
	return false


func test_default_config_matches_the_schema() -> void:
	assert_array(TuneConfig.load_default().problems()).is_empty()


func test_every_schema_key_is_in_the_default_file() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	for section: String in TuneSchema.KEYS:
		for key: String in TuneSchema.KEYS[section]:
			assert_bool(config.has(section, key)).override_failure_message(
				"missing %s/%s" % [section, key]
			).is_true()


func test_wrong_type_is_reported() -> void:
	var config: TuneConfig = _with_line("cool_rate=0.1", "cool_rate=1")
	assert_bool(_has_problem(config, "cooling/cool_rate")).is_true()


func test_missing_key_is_reported() -> void:
	var config: TuneConfig = _with_line("min_size=20\n", "")
	assert_bool(_has_problem(config, "deck/min_size")).is_true()


func test_unknown_key_is_reported() -> void:
	var config: TuneConfig = _with_line("min_size=20\n", "min_size=20\nmax_size=60\n")
	assert_bool(_has_problem(config, "deck/max_size")).is_true()


func test_unknown_section_is_reported() -> void:
	var config: TuneConfig = TuneConfig.parse(_default_text() + "\n[roulette]\nzero=1\n")
	assert_bool(_has_problem(config, "roulette")).is_true()


func test_list_of_wrong_length_is_reported() -> void:
	var config: TuneConfig = _with_line(
		"house_swap_chance=[0.2, 0.35, 0.5, 0.65, 0.8]", "house_swap_chance=[0.2, 0.35]"
	)
	assert_bool(_has_problem(config, "consequences/house_swap_chance")).is_true()


func test_list_with_wrong_entry_type_is_reported() -> void:
	var config: TuneConfig = _with_line(
		"multiplier_values=[1.0, 1.5, 2.0]", "multiplier_values=[1.0, 1.5, 2]"
	)
	assert_bool(_has_problem(config, "heat/multiplier_values")).is_true()


func test_multiplier_points_must_pair_up() -> void:
	var uneven: TuneConfig = _with_line(
		"multiplier_ratios=[1.0, 2.0, 3.0]", "multiplier_ratios=[1.0, 2.0]"
	)
	assert_bool(_has_problem(uneven, "multiplier_ratios and multiplier_values")).is_true()
	var text: String = _default_text()
	text = text.replace("multiplier_ratios=[1.0, 2.0, 3.0]", "multiplier_ratios=[1.0]")
	text = text.replace("multiplier_values=[1.0, 1.5, 2.0]", "multiplier_values=[1.0]")
	assert_bool(_has_problem(TuneConfig.parse(text), "at least 2")).is_true()


func test_multiplier_points_load() -> void:
	# Spec §1.1: m(1)=1, m(2)=1.5, m(3)=2.
	var config: TuneConfig = TuneConfig.load_default()
	assert_array(config.get_float_list("heat", "multiplier_ratios")).is_equal([1.0, 2.0, 3.0])
	assert_array(config.get_float_list("heat", "multiplier_values")).is_equal([1.0, 1.5, 2.0])


func test_floor_table_loads() -> void:
	# Spec §6.3.
	var config: TuneConfig = TuneConfig.load_default()
	assert_int(config.get_int("floors", "start_bankroll")).is_equal(50000)
	assert_array(config.get_int_list("floors", "quotas")).is_equal(
		[140000, 700000, 3500000, 17500000, 87500000]
	)
	assert_array(config.get_int_list("floors", "high_stakes_max")).is_equal(
		[20000, 100000, 500000, 2500000, 12500000]
	)


func test_scalar_values_load() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	# Spec §4.1, §1.6, §4.2, §9.
	assert_int(config.get_int("deck", "min_size")).is_equal(20)
	assert_float(config.get_float("cooling", "cool_rate")).is_equal_approx(0.1, 0.0001)
	assert_float(config.get_float("deck", "floor_per_luminous_mark")).is_equal_approx(0.5, 0.0001)
	assert_int(config.get_int("items", "ink_charges_per_floor")).is_equal(2)


func test_blackjack_rules_load_from_config() -> void:
	# Spec §3.1 house rules.
	var rules: BlackjackRules = BlackjackRules.from_config(TuneConfig.load_default())
	assert_int(rules.bust_threshold).is_equal(23)
	assert_int(rules.natural_payout_num).is_equal(3)
	assert_int(rules.natural_payout_den).is_equal(2)
	assert_int(rules.dealer_stand).is_equal(17)
	assert_bool(rules.dealer_hits_soft_17).is_true()
	assert_int(rules.max_split_hands).is_equal(4)
	assert_int(rules.insurance_max_pct).is_equal(50)
	assert_int(rules.insurance_payout_num).is_equal(2)
	assert_int(rules.insurance_payout_den).is_equal(1)


func test_baccarat_rules_load_from_config() -> void:
	# Spec §3.2 payouts.
	var rules: BaccaratRules = BaccaratRules.from_config(TuneConfig.load_default())
	assert_int(rules.banker_commission_pct).is_equal(5)
	assert_int(rules.tie_payout_num).is_equal(8)
	assert_int(rules.tie_payout_den).is_equal(1)


func test_debug_bet_loads() -> void:
	assert_int(TuneConfig.load_default().get_int("debug", "debug_bet")).is_equal(1000)
