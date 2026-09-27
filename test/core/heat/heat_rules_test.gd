extends GdUnitTestSuite
## The bet-change multiplier m(r) (spec §1.1) and the table heat tiers (§7.1).

var _rules: HeatRules


func before_test() -> void:
	_rules = HeatRules.from_config(TuneConfig.load_default())


## §1.1 starting proposal: m(1) = 1, m(2) = 1.5, m(3) = 2.
func test_multiplier_passes_through_its_points(
	# gdlint: ignore=unused-argument
	r: float, m: float, test_parameters: Array = [[1.0, 1.0], [2.0, 1.5], [3.0, 2.0]]
) -> void:
	assert_float(_rules.multiplier(r)).is_equal_approx(m, 0.0001)


func test_multiplier_is_linear_between_points() -> void:
	assert_float(_rules.multiplier(1.5)).is_equal_approx(1.25, 0.0001)
	assert_float(_rules.multiplier(2.5)).is_equal_approx(1.75, 0.0001)


func test_multiplier_holds_past_the_last_point() -> void:
	assert_float(_rules.multiplier(5.0)).is_equal_approx(2.0, 0.0001)


## §3.2: a side switch counts as r = 3, the largest change the limits allow.
func test_largest_ratio_is_three() -> void:
	assert_float(_rules.max_ratio).is_equal_approx(3.0, 0.0001)


## §1.3: the largest change is the bigger of the raise cap and the decrease floor.
func test_largest_ratio_follows_a_deeper_decrease_floor() -> void:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	text = text.replace("min_decrease_pct=50", "min_decrease_pct=25")
	var config: TuneConfig = TuneConfig.parse(text)
	assert_float(HeatRules.from_config(config).max_ratio).is_equal_approx(4.0, 0.0001)


## §7.1: 30 Watched, 60 Marked, 90 Backed off.
func test_tier_of_heat(
	heat: float,
	tier: int,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[0.0, HeatTier.Kind.CLEAN],
		[29.9, HeatTier.Kind.CLEAN],
		[30.0, HeatTier.Kind.WATCHED],
		[59.9, HeatTier.Kind.WATCHED],
		[60.0, HeatTier.Kind.MARKED],
		[89.9, HeatTier.Kind.MARKED],
		[90.0, HeatTier.Kind.BACKED_OFF],
		[140.0, HeatTier.Kind.BACKED_OFF],
	]
) -> void:
	assert_int(_rules.tier_of(heat)).is_equal(tier)


## §7.1: Watched ×1.5, Marked ×2.
func test_tier_cost_multipliers(
	tier: int,
	multiplier: float,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[HeatTier.Kind.CLEAN, 1.0],
		[HeatTier.Kind.WATCHED, 1.5],
		[HeatTier.Kind.MARKED, 2.0],
	]
) -> void:
	assert_float(_rules.cost_multiplier(tier as HeatTier.Kind)).is_equal_approx(multiplier, 0.0001)
