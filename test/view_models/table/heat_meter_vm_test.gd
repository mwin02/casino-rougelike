extends GdUnitTestSuite
## The heat meter on the real table (spec §7.1): whole-number heat, its
## tier, where the tier edges and the heat floor sit on the bar, and where an
## action being weighed would take it. Edges are read from config.

var _rules: HeatRules


func before_test() -> void:
	_rules = HeatRules.from_config(TuneConfig.load_default())


func _meter(heat: float, pending: float = 0.0, heat_floor: float = 0.0) -> HeatMeterVM:
	return HeatMeterVM.new(_rules, heat, heat_floor, pending)


func _edge(tier: HeatTier.Kind) -> float:
	return _rules.tier_thresholds[tier - 1]


# gdlint: ignore=unused-argument
func test_each_tier_shows_its_name(heat_share: float, expected: String, test_parameters: Array = [
	[0.0, "Clean"], [0.4, "Watched"], [0.7, "Marked"], [1.2, "Backed off"],
]) -> void:
	var meter: HeatMeterVM = _meter(heat_share * _edge(HeatTier.Kind.BACKED_OFF))
	assert_str(meter.tier_name()).is_equal(expected)


func test_heat_on_an_edge_is_in_the_higher_tier() -> void:
	assert_int(_meter(_edge(HeatTier.Kind.WATCHED)).tier()).is_equal(HeatTier.Kind.WATCHED)
	assert_int(_meter(_edge(HeatTier.Kind.MARKED)).tier()).is_equal(HeatTier.Kind.MARKED)
	assert_int(_meter(_edge(HeatTier.Kind.BACKED_OFF)).tier()).is_equal(HeatTier.Kind.BACKED_OFF)


func test_heat_shows_as_a_whole_number() -> void:
	assert_str(_meter(18.4).heat_text()).is_equal("18")


func test_edges_sit_on_the_bar_in_order_below_the_top() -> void:
	var edges: Array[float] = _meter(0.0).edge_fractions()
	assert_int(edges.size()).is_equal(_rules.tier_thresholds.size())
	assert_float(edges[2]).is_equal_approx(HeatMeterVM.TOP_EDGE_AT, 0.0001)
	assert_float(edges[0] / edges[2]).is_equal_approx(
		_edge(HeatTier.Kind.WATCHED) / _edge(HeatTier.Kind.BACKED_OFF), 0.0001
	)


func test_edges_move_with_the_config() -> void:
	_rules.tier_thresholds = [10.0, 20.0, 40.0]
	var meter: HeatMeterVM = _meter(20.0)
	assert_str(meter.tier_name()).is_equal("Marked")
	assert_float(meter.fill_fraction()).is_equal_approx(HeatMeterVM.TOP_EDGE_AT / 2.0, 0.0001)


func test_the_fill_stops_at_the_top_of_the_bar() -> void:
	assert_float(_meter(_edge(HeatTier.Kind.BACKED_OFF) * 3.0).fill_fraction()).is_equal(1.0)


func test_the_heat_floor_has_its_place_on_the_bar() -> void:
	var meter: HeatMeterVM = _meter(30.0, 0.0, 9.0)
	assert_bool(meter.has_floor()).is_true()
	assert_float(meter.floor_fraction() / meter.fill_fraction()).is_equal_approx(0.3, 0.0001)
	assert_bool(_meter(30.0).has_floor()).is_false()


func test_nothing_is_projected_without_pending_heat() -> void:
	var meter: HeatMeterVM = _meter(18.0)
	assert_bool(meter.has_projection()).is_false()
	assert_str(meter.projected_text()).is_equal("")


func test_pending_heat_projects_where_the_table_would_land() -> void:
	var meter: HeatMeterVM = _meter(18.0, 9.4)
	assert_bool(meter.has_projection()).is_true()
	assert_str(meter.projected_text()).is_equal("→ 27")
	assert_float(meter.projected_fraction()).is_greater(meter.fill_fraction())
	assert_bool(meter.crosses_tier()).is_false()


func test_a_projection_over_an_edge_names_the_tier_it_reaches() -> void:
	var meter: HeatMeterVM = _meter(_edge(HeatTier.Kind.WATCHED) - 2.0, 5.0)
	assert_str(meter.tier_name()).is_equal("Clean")
	assert_bool(meter.crosses_tier()).is_true()
	assert_str(meter.projected_tier_name()).is_equal("Watched")


func test_bands_name_each_tier_and_its_range() -> void:
	_rules.tier_thresholds = [45.0, 90.0, 135.0]
	var texts: Array[String] = []
	for band: HeatMeterVM.Band in _meter(0.0).bands():
		texts.append("%s %s" % [band.name, band.range_text])
	assert_array(texts).contains_exactly(
		["Clean 0–45", "Watched 45–90", "Marked 90–135", "Backed off 135+"]
	)
