extends GdUnitTestSuite
## What a floor remembers for the map screen (block U4): the nodes walked,
## in order, and the size of the pool its clock started with. Both save
## with the floor.

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new()


func test_a_new_floor_has_walked_nowhere() -> void:
	assert_array(_f.three_rows().walked).is_empty()


func test_each_node_entered_joins_the_walk_in_order() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	assert_array(floor.walked).contains_exactly([
		floor.map.node_at(0, 1), floor.map.node_at(1, 2),
	])


func test_a_refused_move_is_not_walked() -> void:
	var floor: Floor = _f.three_rows()
	assert_bool(floor.enter(floor.map.node_at(2, 1))).is_false()
	assert_array(floor.walked).is_empty()


func test_the_clock_keeps_the_pool_it_started_with() -> void:
	var floor: Floor = _f.three_rows()
	var pool: int = _f.config.get_int("clock", "hands_per_floor")
	assert_int(floor.clock.total).is_equal(pool)
	floor.enter(floor.map.node_at(0, 1))
	FloorFixture.play(floor, 3)
	assert_int(floor.clock.hands_left).is_equal(pool - 3)
	assert_int(floor.clock.total).is_equal(pool)


func test_late_night_bought_mid_floor_grows_the_pool() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	var pool: int = floor.clock.total
	floor.shop.offers = [ItemKind.Kind.LATE_NIGHT]
	assert_bool(floor.shop.buy_item(ItemKind.Kind.LATE_NIGHT)).is_true()
	floor.leave()
	var late: int = _f.config.get_int("items", "late_night_hands")
	assert_int(floor.clock.total).is_equal(pool + late)


func test_the_walk_and_the_pool_save_with_the_floor() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	FloorFixture.play(floor, 2)
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	var restored: Floor = Floor.from_dict(
		floor.to_dict(), _f.config, _f.run, _f.deck, _f.layer, _f.kit, _f.rng
	)
	assert_dict(restored.to_dict()).is_equal(floor.to_dict())
	assert_int(restored.clock.total).is_equal(floor.clock.total)
	assert_array(restored.walked).contains_exactly([
		restored.map.node_at(0, 1), restored.map.node_at(1, 0),
	])


func test_a_save_whose_walk_leaves_the_map_is_refused() -> void:
	var run: Run = Run.start(_f.config, 5)
	run.floor.enter(run.floor.choices()[0])
	var saved: Dictionary = run.to_dict()
	assert_object(SaveStore.from_saved(saved, _f.config)).is_not_null()
	var saved_floor: Dictionary = saved["floor"]
	saved_floor["walked"] = [[99, 99]]
	assert_object(SaveStore.from_saved(saved, _f.config)).is_null()
