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


## Block 7: the total bet never passes the bankroll.
func test_bankroll_cap_binds_when_tighter() -> void:
	var limits: BetLimits = _limits(1000)
	limits.bankroll_cap = 2500
	assert_int(limits.max_total()).is_equal(2500)
	assert_bool(limits.allows(2501)).is_false()


func test_bankroll_cap_leaves_looser_limits_alone() -> void:
	var limits: BetLimits = _limits(1000)
	limits.bankroll_cap = 50000
	assert_int(limits.max_total()).is_equal(3000)


func test_no_bankroll_cap_by_default() -> void:
	assert_int(_limits(1000).bankroll_cap).is_equal(BetLimits.NO_CAP)
