extends GdUnitTestSuite
## Walking a floor (spec §5.2, §6.1): the player enters a linked node one
## row at a time. At a table node they sit at one of its tables; only table
## hands spend the clock. Back rooms cost no hands. Leaving the last row, or
## leaving a table once the clock is out, goes to the quota check.

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new()


func test_the_first_choices_are_the_first_row() -> void:
	var floor: Floor = _f.three_rows()
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)
	assert_array(floor.choices()).contains_exactly([floor.map.node_at(0, 1)])


func test_only_a_linked_node_can_be_entered() -> void:
	var floor: Floor = _f.three_rows()
	assert_bool(floor.enter(floor.map.node_at(2, 1))).is_false()
	assert_bool(floor.enter(floor.map.node_at(0, 1))).is_true()
	floor.leave()
	assert_array(floor.choices()).contains_exactly(
		[floor.map.node_at(1, 0), floor.map.node_at(1, 2)]
	)
	assert_bool(floor.enter(floor.map.node_at(2, 1))).is_false()


func test_the_clock_starts_with_last_floors_extra_hands() -> void:
	_f.run.extra_hands = 3
	var hands: int = _f.config.get_int("clock", "hands_per_floor")
	assert_int(_f.three_rows().clock.hands_left).is_equal(hands + 3)


func test_table_hands_spend_the_floor_clock() -> void:
	var floor: Floor = _f.three_rows()
	var start: int = floor.clock.hands_left
	floor.enter(floor.map.node_at(0, 1))
	FloorFixture.play(floor, 2)
	assert_int(floor.clock.hands_left).is_equal(start - 2)


func test_a_table_can_be_sat_at_once_and_only_when_affordable() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	assert_object(floor.sit(1)).is_null()
	assert_object(floor.sit(0)).is_not_null()
	assert_object(floor.sit(0)).is_null()
	var broke: FloorFixture = FloorFixture.new(999)
	var poor: Floor = broke.three_rows()
	poor.enter(poor.map.node_at(0, 1))
	assert_object(poor.sit(0)).is_null()


func test_leaving_a_table_banks_its_money_and_run_heat() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = FloorFixture.play(floor, 1)
	session.table_heat.heat = 50.0
	var bankroll: int = session.bankroll
	assert_bool(floor.leave()).is_true()
	assert_int(_f.run.bankroll).is_equal(bankroll)
	var share: float = _f.config.get_float("run_heat", "stand_up_rollover")
	assert_float(_f.run.run_heat).is_equal_approx(50.0 * share, 0.0001)
	assert_object(floor.session).is_null()


func test_a_table_cannot_be_left_mid_hand() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	session.start_hand(session.table.table_min)
	assert_bool(floor.leave()).is_false()
	assert_int(floor.phase).is_equal(Floor.Phase.AT_TABLE)


func test_a_table_node_can_be_left_without_sitting() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	assert_bool(floor.leave()).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_a_shop_spends_no_hands_and_banks_its_purchases() -> void:
	var floor: Floor = _f.three_rows()
	var start: int = floor.clock.hands_left
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	assert_int(floor.phase).is_equal(Floor.Phase.AT_STOP)
	assert_object(floor.services).is_null()
	assert_bool(floor.shop.buy_extra_hand()).is_true()
	var paid: int = floor.shop.extra_hand_price()
	floor.leave()
	assert_int(floor.clock.hands_left).is_equal(start)
	assert_int(_f.run.bankroll).is_equal(50_000 - paid)
	assert_int(floor.extra_hands_bought).is_equal(1)


func test_extra_hands_count_toward_the_cap_across_shops() -> void:
	var cap: int = _f.config.get_int("clock", "extra_hands_cap")
	var floor: Floor = _f.floor_on([
		_f.back_room(0, 0, MapNode.Kind.SHOP, [0]),
		_f.tables(1, 0, [0]),
		_f.back_room(2, 0, MapNode.Kind.SHOP, [0]),
		_f.tables(3, 0, []),
	])
	floor.enter(floor.map.node_at(0, 0))
	for i: int in cap - 1:
		floor.shop.buy_extra_hand()
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 0))
	assert_bool(floor.shop.buy_extra_hand()).is_true()
	assert_bool(floor.shop.can_buy_extra_hand()).is_false()


func test_deck_services_spend_no_hands_and_bank_their_price() -> void:
	var floor: Floor = _f.three_rows()
	var start: int = floor.clock.hands_left
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	assert_object(floor.shop).is_null()
	var price: int = floor.services.price(DeckServices.Service.REMOVE)
	assert_bool(floor.services.remove(0)).is_true()
	floor.leave()
	assert_int(floor.clock.hands_left).is_equal(start)
	assert_int(_f.run.bankroll).is_equal(50_000 - price)
	assert_int(_f.deck.size()).is_equal(51)


func test_deck_services_price_at_the_floor_quota() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	var expected: int = ShopPricing.from_config(_f.config, 1).price(
		_f.config.get_int("shop", "addition_pct")
	)
	assert_int(floor.services.price(DeckServices.Service.ADD)).is_equal(expected)


func test_leaving_the_last_row_goes_to_the_quota_check() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	floor.leave()
	assert_int(floor.phase).is_equal(Floor.Phase.QUOTA_CHECK)
	assert_array(floor.choices()).is_empty()


func test_running_out_of_hands_goes_to_the_quota_check_mid_map() -> void:
	var hands: int = _f.config.get_int("clock", "hands_per_floor")
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	floor.clock.hands_left = 1
	FloorFixture.play(floor, 1)
	assert_bool(session.can_start_hand(session.table.table_min)).is_false()
	floor.leave()
	assert_int(floor.phase).is_equal(Floor.Phase.QUOTA_CHECK)
	assert_int(hands).is_greater(1)
