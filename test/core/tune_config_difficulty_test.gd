extends GdUnitTestSuite
## Run difficulty in config (spec §6.3): each level's values are written over
## the shared sections, and the file is checked level by level.


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


## The default file with one line swapped out inside one level's section.
func _with_level_line(level: int, old: String, new: String) -> String:
	var text: String = _default_text()
	var start: int = text.find("[difficulty_%d]" % level)
	var at: int = text.find(old, start)
	assert_int(at).is_greater(start)
	return text.substr(0, at) + new + text.substr(at + old.length())


func _level_value(level: int, key: String) -> Variant:
	var file: ConfigFile = ConfigFile.new()
	file.parse(_default_text())
	return file.get_value("difficulty_%d" % level, key)


func _ranges(config: TuneConfig) -> Array:
	var result: Array = []
	for key: String in TuneSchema.KEYS["table_rolls"]:
		result.append(config.get_float_list("table_rolls", key))
	return result


func test_default_load_is_at_the_default_level() -> void:
	# Plan block 18: medium (level 2) until the run-start screen offers a choice.
	var config: TuneConfig = TuneConfig.load_default()
	assert_int(config.difficulty()).is_equal(2)
	assert_array(config.levels()).is_equal([0, 2, 4])
	assert_array(config.get_int_list("floors", "quotas")).is_equal(_level_value(2, "quotas"))


func test_each_levels_values_come_through_the_overlay() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	for level: int in config.levels():
		var at: TuneConfig = config.for_difficulty(level)
		assert_int(at.difficulty()).is_equal(level)
		assert_array(at.problems()).is_empty()
		for key: String in ["quotas", "low_stakes_min", "low_stakes_max", "high_stakes_min"]:
			assert_array(at.get_int_list("floors", key)).is_equal(_level_value(level, key))
		assert_array(at.get_int_list("floors", "high_stakes_max")).is_equal(
			_level_value(level, "high_stakes_max")
		)
		assert_int(at.get_int("shop", "run_price_pct")).is_equal(_level_value(level, "run_price_pct"))


func test_the_roll_shift_moves_every_range() -> void:
	var base: Array = _ranges(TuneConfig.load_default())
	var shifted: TuneConfig = TuneConfig.parse(
		_with_level_line(2, "roll_shift=0.0", "roll_shift=0.1")
	)
	assert_array(shifted.problems()).is_empty()
	var ranges: Array = _ranges(shifted)
	for i: int in base.size():
		var was: Array[float] = base[i]
		var now: Array[float] = ranges[i]
		assert_float(now[0]).is_equal_approx(was[0] + 0.1, 0.0001)
		assert_float(now[1]).is_equal_approx(was[1] + 0.1, 0.0001)


func test_reapplying_a_level_never_stacks_the_shift() -> void:
	var config: TuneConfig = TuneConfig.parse(
		_with_level_line(2, "roll_shift=0.0", "roll_shift=0.1")
	)
	var again: TuneConfig = config.for_difficulty(4).for_difficulty(2)
	assert_array(_ranges(again)).is_equal(_ranges(config))


func test_an_optional_level_key_overrides_the_shared_value() -> void:
	var config: TuneConfig = TuneConfig.parse(
		_with_level_line(0, "run_price_pct=100", "run_price_pct=100\nstart_bankroll=70000")
	)
	assert_array(config.problems()).is_empty()
	assert_int(config.for_difficulty(0).get_int("floors", "start_bankroll")).is_equal(70000)


func test_without_it_the_shared_value_stands() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	for level: int in config.levels():
		var at: TuneConfig = config.for_difficulty(level)
		assert_int(at.get_int("floors", "start_bankroll")).is_equal(50000)
		assert_array(at.get_int_list("shop", "floor_price_pct")).is_equal(
			config.get_int_list("shop", "floor_price_pct")
		)


func test_an_unknown_level_is_refused() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	assert_bool(config.has_difficulty(1)).is_false()
	assert_object(config.for_difficulty(1)).is_null()


func test_a_default_level_not_listed_is_reported() -> void:
	var config: TuneConfig = _with_line("default=2", "default=1")
	assert_bool(_has_problem(config, "difficulty/default")).is_true()


func test_a_listed_level_without_a_section_is_reported() -> void:
	var config: TuneConfig = _with_line("levels=[0, 2, 4]", "levels=[0, 2, 4, 6]")
	assert_bool(_has_problem(config, "difficulty_6")).is_true()


func test_a_missing_level_key_is_reported() -> void:
	var text: String = _with_level_line(0, "run_price_pct=100\n", "")
	assert_bool(_has_problem(TuneConfig.parse(text), "difficulty_0/run_price_pct")).is_true()


func test_a_level_list_of_the_wrong_length_is_reported() -> void:
	var text: String = _with_level_line(
		0, "quotas=[140000, 420000, 1260000, 3780000, 11340000]", "quotas=[140000]"
	)
	assert_bool(_has_problem(TuneConfig.parse(text), "difficulty_0/quotas")).is_true()


func test_an_unknown_key_in_a_level_is_reported() -> void:
	var text: String = _with_level_line(0, "run_price_pct=100", "run_price_pct=100\nbonus=1")
	assert_bool(_has_problem(TuneConfig.parse(text), "difficulty_0/bonus")).is_true()


func test_a_level_key_also_set_in_its_section_is_reported() -> void:
	var config: TuneConfig = _with_line(
		"start_bankroll=50000", "start_bankroll=50000\nquotas=[1, 2, 3, 4, 5]"
	)
	assert_bool(_has_problem(config, "floors/quotas is set per difficulty")).is_true()
