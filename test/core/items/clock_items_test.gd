extends GdUnitTestSuite
## The clock items and Permanent Ink's charges (spec §9): Late Night lengthens
## every floor, Comped Breakfast carries unused hands on, and Ink refills as
## each floor starts.

var _rules: ItemRules


func before_test() -> void:
	_rules = ItemRules.from_config(TuneConfig.load_default())


func test_late_night_adds_hands_to_every_floor() -> void:
	var floors: FloorFixture = FloorFixture.new()
	var hands: int = floors.config.get_int("clock", "hands_per_floor")
	floors.kit.add_item(ItemKind.Kind.LATE_NIGHT, _rules)
	assert_int(_rules.late_night_hands).is_equal(5)
	assert_int(floors.three_rows().clock.hands_left).is_equal(hands + 5)


func test_comped_breakfast_carries_unused_hands_instead_of_shedding_them() -> void:
	var floors: FloorFixture = FloorFixture.new(140_000)
	floors.run.run_heat = 80.0
	floors.kit.add_item(ItemKind.Kind.COMPED_BREAKFAST, _rules)
	var floor: Floor = floors.three_rows()
	floor.clock.hands_left = 12
	floor.cash_out()
	var per_hand: float = floors.config.get_float("run_heat", "cash_out_shed_per_hand")
	assert_int(_rules.breakfast_carry_max).is_equal(10)
	assert_int(floor.carried_hands).is_equal(10)
	assert_float(floor.run_heat_shed).is_equal_approx(2 * per_hand, 0.0001)
	floor.check_quota()
	floor.finish()
	var hands: int = floors.config.get_int("clock", "hands_per_floor")
	assert_int(floors.three_rows().clock.hands_left).is_equal(hands + 10)


func test_a_floor_carries_no_hands_without_comped_breakfast() -> void:
	var floors: FloorFixture = FloorFixture.new(140_000)
	var floor: Floor = floors.three_rows()
	floor.cash_out()
	assert_int(floor.carried_hands).is_equal(0)


func test_permanent_ink_charges_at_once_and_refill_each_floor() -> void:
	var floors: FloorFixture = FloorFixture.new()
	floors.kit.add_item(ItemKind.Kind.PERMANENT_INK, _rules)
	assert_int(floors.kit.ink_charges).is_equal(_rules.ink_charges_per_floor)
	floors.kit.ink_charges = 0
	floors.three_rows()
	assert_int(floors.kit.ink_charges).is_equal(_rules.ink_charges_per_floor)


func test_discarding_permanent_ink_drops_its_charges() -> void:
	var floors: FloorFixture = FloorFixture.new()
	floors.kit.add_item(ItemKind.Kind.PERMANENT_INK, _rules)
	floors.kit.remove_item(ItemKind.Kind.PERMANENT_INK)
	assert_int(floors.kit.ink_charges).is_equal(0)


func test_a_floor_gives_no_ink_without_the_item() -> void:
	var floors: FloorFixture = FloorFixture.new()
	floors.three_rows()
	assert_int(floors.kit.ink_charges).is_equal(0)
