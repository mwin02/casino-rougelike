class_name ShopPricing
extends RefCounted
## Every shop price (spec §6.4): base percent × the floor's quota × the
## floor's price multiplier × the run's, rounded down once (§6.2). The quota
## is the configured one; a marker loan never raises prices. The run
## multiplier is the hook for run difficulty settings.

var quota: int
## Percents: 100 is ×1.
var floor_pct: int
var run_pct: int


func _init(p_quota: int, p_floor_pct: int, p_run_pct: int) -> void:
	quota = p_quota
	floor_pct = p_floor_pct
	run_pct = p_run_pct


static func from_config(config: TuneConfig, floor_number: int) -> ShopPricing:
	var index: int = floor_number - 1
	return ShopPricing.new(
		config.get_int_list("floors", "quotas")[index],
		config.get_int_list("shop", "floor_price_pct")[index],
		config.get_int("shop", "run_price_pct"),
	)


func price(base_pct: int) -> int:
	return Money.apply_ratio(quota, base_pct * floor_pct * run_pct, 1_000_000)
