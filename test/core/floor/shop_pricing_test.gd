extends GdUnitTestSuite
## Shop prices (spec §6.4): base percent × floor quota × the floor's price
## multiplier × the run's, rounded down once (§6.2).


func test_a_price_is_a_share_of_the_quota() -> void:
	var pricing: ShopPricing = ShopPricing.new(140_000, 100, 100)
	assert_int(pricing.price(2)).is_equal(2_800)
	assert_int(pricing.price(15)).is_equal(21_000)


func test_floor_and_run_multipliers_scale_the_price() -> void:
	assert_int(ShopPricing.new(100_000, 150, 100).price(10)).is_equal(15_000)
	assert_int(ShopPricing.new(100_000, 100, 120).price(10)).is_equal(12_000)
	assert_int(ShopPricing.new(100_000, 150, 120).price(10)).is_equal(18_000)


func test_the_price_rounds_down_once() -> void:
	# 999 × 3% × 1.11 × 1.11 = 36.92...: one rounding gives 36, rounding each
	# step would give 29 × 1.11 = 32 → 35.
	assert_int(ShopPricing.new(999, 111, 111).price(3)).is_equal(36)


func test_from_config_reads_the_floor_quota_and_multipliers() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var quota: int = config.get_int_list("floors", "quotas")[1]
	var floor_pct: int = config.get_int_list("shop", "floor_price_pct")[1]
	var run_pct: int = config.get_int("shop", "run_price_pct")
	var expected: int = Money.apply_ratio(quota, 10 * floor_pct * run_pct, 1_000_000)
	assert_int(ShopPricing.from_config(config, 2).price(10)).is_equal(expected)
