extends GdUnitTestSuite
## House rules in config (spec §5.2, §5.3): a [house_rule_<name>] section
## names a game and the values it changes, and for_house_rule() writes them
## over that game's section and [side_bets].

const RULE: String = "bust_23"


func _default_text() -> String:
	return FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)


## The default file with one more house rule section at the end.
func _with_rule(name: String, lines: String) -> TuneConfig:
	return TuneConfig.parse("%s\n[house_rule_%s]\n\n%s\n" % [_default_text(), name, lines])


func _has_problem(config: TuneConfig, fragment: String) -> bool:
	for problem: String in config.problems():
		if problem.contains(fragment):
			return true
	return false


func _rule_value(name: String, key: String) -> Variant:
	var file: ConfigFile = ConfigFile.new()
	file.parse(_default_text())
	return file.get_value("house_rule_%s" % name, key)


## A value through the typed getter its schema kind calls for.
func _read(config: TuneConfig, section: String, key: String) -> Variant:
	var kind: TuneSchema.Kind = TuneSchema.KEYS[section][key][0]
	match kind:
		TuneSchema.Kind.INT:
			return config.get_int(section, key)
		TuneSchema.Kind.FLOAT:
			return config.get_float(section, key)
		TuneSchema.Kind.BOOL:
			return config.get_bool(section, key)
		TuneSchema.Kind.INT_LIST:
			return Array(config.get_int_list(section, key))
	return Array(config.get_float_list(section, key))


func test_the_default_file_lists_its_rules_with_no_problems() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	assert_array(config.problems()).is_empty()
	assert_array(config.house_rules()).contains([RULE])
	assert_str(config.house_rule_game(RULE)).is_equal("blackjack")
	assert_array(config.applied_house_rules()).is_empty()


func test_every_rule_in_the_file_comes_through_the_overlay() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var file: ConfigFile = ConfigFile.new()
	file.parse(_default_text())
	for name: String in config.house_rules():
		var at: TuneConfig = config.for_house_rule(name)
		assert_array(at.problems()).is_empty()
		var section: String = "house_rule_%s" % name
		for key: String in file.get_section_keys(section):
			if key == TuneSchema.HOUSE_RULE_GAME:
				continue
			var target: PackedStringArray = key.split(".")
			assert_bool(at.has(target[0], target[1])).is_true()
			assert_str(var_to_str(_read(at, target[0], target[1]))).is_equal(
				var_to_str(file.get_value(section, key))
			)


func test_a_rules_values_come_through_the_overlay() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var at: TuneConfig = config.for_house_rule(RULE)
	assert_array(at.problems()).is_empty()
	assert_array(at.applied_house_rules()).is_equal([RULE])
	assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(
		_rule_value(RULE, "blackjack.bust_threshold")
	)
	# Spec §3.1: the house rule is a bust at 23.
	assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(23)


func test_the_overlay_leaves_the_base_config_alone() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var before: int = config.get_int("blackjack", "bust_threshold")
	config.for_house_rule(RULE)
	assert_int(config.get_int("blackjack", "bust_threshold")).is_equal(before)
	assert_array(config.applied_house_rules()).is_empty()


func test_a_rule_changes_only_the_keys_it_names() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var at: TuneConfig = config.for_house_rule(RULE)
	assert_int(at.get_int("blackjack", "dealer_stand")).is_equal(
		config.get_int("blackjack", "dealer_stand")
	)
	assert_array(at.get_int_list("side_bets", "perfect_pairs")).is_equal(
		config.get_int_list("side_bets", "perfect_pairs")
	)


func test_an_unknown_rule_is_refused() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	assert_bool(config.has_house_rule("no_such_rule")).is_false()
	assert_object(config.for_house_rule("no_such_rule")).is_null()


func test_a_rule_stacks_on_a_difficulty() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	for level: int in config.levels():
		var at: TuneConfig = config.for_difficulty(level).for_house_rule(RULE)
		assert_int(at.difficulty()).is_equal(level)
		assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(23)
		assert_array(at.get_int_list("floors", "quotas")).is_equal(
			config.for_difficulty(level).get_int_list("floors", "quotas")
		)


func test_changing_the_difficulty_keeps_the_rule() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var at: TuneConfig = config.for_house_rule(RULE).for_difficulty(0)
	assert_array(at.applied_house_rules()).is_equal([RULE])
	assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(23)


func test_a_second_rule_stacks_on_the_first() -> void:
	# §5.3: a floor's rule first, then the table's.
	var config: TuneConfig = _with_rule(
		"short_pairs", 'game="any"\nside_bets.perfect_pairs=[8, 20]'
	)
	assert_array(config.problems()).is_empty()
	var at: TuneConfig = config.for_house_rule(RULE).for_house_rule("short_pairs")
	assert_array(at.applied_house_rules()).is_equal([RULE, "short_pairs"])
	assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(23)
	assert_array(at.get_int_list("side_bets", "perfect_pairs")).is_equal([8, 20])


func test_applying_a_rule_twice_changes_nothing() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var at: TuneConfig = config.for_house_rule(RULE).for_house_rule(RULE)
	assert_array(at.applied_house_rules()).is_equal([RULE])


func test_a_rule_may_change_its_games_side_bets() -> void:
	var config: TuneConfig = _with_rule(
		"loose", 'game="blackjack"\nblackjack.bust_threshold=24\nside_bets.bust_it=[2, 3, 9, 40, 150]'
	)
	assert_array(config.problems()).is_empty()
	var at: TuneConfig = config.for_house_rule("loose")
	assert_array(at.get_int_list("side_bets", "bust_it")).is_equal([2, 3, 9, 40, 150])
