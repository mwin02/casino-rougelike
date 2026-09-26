extends GdUnitTestSuite
## Adjust limits (spec §1.3): the total bet stays within 3× and 0.5× of the
## opening bet, and within the table's min and max.


func _limits(opening: int, table_min: int = 1, table_max: int = 1000000) -> BetLimits:
	return BetLimits.from_config(TuneConfig.load_default(), opening, table_min, table_max)


func test_raises_cap_at_three_times_the_opening_bet() -> void:
	# §1.3 [TUNE]: 3× to start.
	assert_int(_limits(1000).max_total()).is_equal(3000)


func test_decreases_floor_at_half_the_opening_bet() -> void:
	# §1.3 [TUNE]: 0.5× to start.
	assert_int(_limits(1000).min_total()).is_equal(500)


func test_decrease_floor_rounds_up() -> void:
	assert_int(_limits(1001).min_total()).is_equal(501)


func test_table_max_binds_when_tighter() -> void:
	assert_int(_limits(1000, 1, 2000).max_total()).is_equal(2000)


func test_table_min_binds_when_tighter() -> void:
	assert_int(_limits(1000, 800).min_total()).is_equal(800)


func test_allows_only_totals_within_both_limits() -> void:
	var limits: BetLimits = _limits(1000)
	assert_bool(limits.allows(500)).is_true()
	assert_bool(limits.allows(3000)).is_true()
	assert_bool(limits.allows(499)).is_false()
	assert_bool(limits.allows(3001)).is_false()
