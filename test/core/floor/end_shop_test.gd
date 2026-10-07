extends GdUnitTestSuite
## The end-of-floor shop (spec §6.5): open only once the quota check is
## passed, before the elevator. It sells extra hands and deck services.
## Spending there can take the bankroll below the quota but never below the
## next floor's low-stakes minimum. Finishing banks it all into the run.

const QUOTA: int = 140_000

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new(QUOTA)


func _passed() -> Floor:
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	return floor


func test_the_end_shop_opens_only_after_passing() -> void:
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	assert_object(floor.shop).is_null()
	floor.check_quota()
	assert_object(floor.shop).is_not_null()
	assert_object(floor.shop.services).is_not_null()
	_f = FloorFixture.new(1_000)
	var lost: Floor = _f.three_rows()
	lost.enter(lost.map.node_at(0, 1))
	lost.leave()
	lost.enter(lost.map.node_at(1, 0))
	lost.leave()
	lost.enter(lost.map.node_at(2, 1))
	lost.leave()
	lost.check_quota()
	assert_object(lost.shop).is_null()


func test_the_end_shop_keeps_the_next_floors_low_stakes_minimum() -> void:
	var next_min: int = _f.config.get_int_list("floors", "low_stakes_min")[1]
	var floor: Floor = _passed()
	assert_int(floor.next_floor_min).is_equal(next_min)
	var hand: int = floor.shop.extra_hand_price()
	floor.shop.services.bankroll = next_min + hand
	assert_bool(floor.shop.buy_extra_hand()).is_true()
	assert_bool(floor.shop.can_buy_extra_hand()).is_false()
	assert_int(floor.shop.bankroll()).is_equal(next_min)


func test_spending_below_the_quota_at_the_end_shop_is_fine() -> void:
	var floor: Floor = _passed()
	floor.shop.services.full_reforge(0, 13, Card.Suit.SPADES)
	assert_int(floor.shop.bankroll()).is_less(QUOTA)
	floor.finish()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)
	assert_bool(_f.run.lost).is_false()
	assert_int(_f.run.bankroll).is_less(QUOTA)


func test_finishing_carries_extra_hands_and_moves_up_a_floor() -> void:
	_f.run.bankroll = QUOTA + 10_000
	var floor: Floor = _f.floor_on([
		_f.back_room(0, 0, MapNode.Kind.SHOP, [0]),
		_f.tables(1, 0, []),
	])
	floor.enter(floor.map.node_at(0, 0))
	floor.shop.buy_extra_hand()
	floor.leave()
	floor.cash_out()
	floor.check_quota()
	floor.shop.buy_extra_hand()
	floor.finish()
	assert_int(_f.run.extra_hands).is_equal(2)
	assert_int(_f.run.floor_number).is_equal(2)
	var hands: int = _f.config.get_int("clock", "hands_per_floor")
	assert_int(_f.three_rows().clock.hands_left).is_equal(hands + 2)


func test_finish_waits_for_the_end_shop() -> void:
	var floor: Floor = _f.three_rows()
	assert_bool(floor.finish()).is_false()
	floor.cash_out()
	assert_bool(floor.finish()).is_false()
	floor.check_quota()
	assert_bool(floor.finish()).is_true()
