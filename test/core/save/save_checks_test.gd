extends GdUnitTestSuite
## A save is checked before anything is built from it (block 14): its shape
## against a template holding one of everything, then the values a shape
## can't catch. A run resumed from disk at a stop, mid-Rummage, at a sweep,
## or after the marker plays on like the run that never stopped.

const PATH: String = "user://test_save_checks.bin"

var _config: TuneConfig = TuneConfig.load_default()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## A run on floor 1 whose floor is three rows: a low table node, then a shop
## and deck services, then a high table node.
func _run() -> Run:
	var run: Run = Run.start(_config, 7)
	var f: FloorFixture = FloorFixture.new()
	var nodes: Array[MapNode] = [
		f.tables(0, 1, [0, 2]),
		f.back_room(1, 0, MapNode.Kind.SHOP, [1]),
		f.back_room(1, 2, MapNode.Kind.DECK_SERVICES, [1]),
		f.tables(2, 1, [], TableStakes.Kind.HIGH),
	]
	run.floor = Floor.new(
		_config, run.state, run.game.deck, run.game.layer, run.kit, run.game.rng,
		FloorMap.from_nodes(3, nodes)
	)
	return run


func _resumed(run: Run) -> Run:
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	var resumed: Run = SaveStore.load_from(_config, PATH)
	assert_object(resumed).is_not_null()
	return resumed


## Plays the rest of the floor the same way on both runs: two hands at each
## table, a tape at the shop, the first sweep choice, then the quota check.
func _finish_floor(run: Run) -> void:
	var floor: Floor = run.floor
	for i: int in 20:
		match floor.phase:
			Floor.Phase.MAP:
				floor.enter(floor.choices()[0])
			Floor.Phase.AT_TABLE:
				if floor.session == null:
					floor.sit(0)
				if floor.session != null:
					FloorFixture.play(floor, 2)
				floor.leave()
			Floor.Phase.AT_STOP:
				if floor.shop != null:
					floor.shop.buy_tape()
				else:
					floor.services.skip_rummage()
				floor.leave()
			Floor.Phase.SWEEP:
				floor.sweep(floor.sweep_choices()[0])
			Floor.Phase.QUOTA_CHECK:
				floor.check_quota()


func _assert_plays_on_alike(a: Run, b: Run) -> void:
	_finish_floor(a)
	_finish_floor(b)
	assert_dict(b.to_dict()).is_equal(a.to_dict())


func _enter_row_1(run: Run, lane: int) -> void:
	run.floor.enter(run.floor.map.node_at(0, 1))
	run.floor.leave()
	run.floor.enter(run.floor.map.node_at(1, lane))


func test_the_template_holds_one_of_everything() -> void:
	var shape: Dictionary = SaveStore._shape(_config)
	var floor: Dictionary = shape["floor"]
	var shop: Dictionary = floor["shop"][0]
	var services: Dictionary = floor["shop_services"][0]
	var kit: Dictionary = shape["kit"]
	assert_array(shape["options"]).is_not_empty()
	assert_array(kit["items"]).is_not_empty()
	assert_array(floor["current"]).is_not_empty()
	assert_array(floor["services"]).is_not_empty()
	assert_array(shop["offers"]).is_not_empty()
	assert_array(services["offer"]).is_not_empty()


func test_a_well_formed_save_loads() -> void:
	var saved: Dictionary = _run().to_dict()
	var floor: Dictionary = saved["floor"]
	floor["current"] = [0, 1]
	assert_object(SaveStore.from_saved(saved, _config)).is_not_null()


func test_values_no_run_can_hold_are_refused(
	key_path: Array,
	value: Variant,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[["state", "floor_number"], 0],
		[["state", "floor_number"], 6],
		[["kit", "items"], [99]],
		[["floor", "current"], [0]],
		[["floor", "current"], [9, 9]],
		[["floor", "phase"], 42],
		[["floor", "signature"], 42],
		[["phase"], 42],
		[["options"], [42]],
	]
) -> void:
	var saved: Dictionary = _run().to_dict()
	var floor: Dictionary = saved["floor"]
	floor["current"] = [0, 1]
	var target: Dictionary = saved
	for i: int in key_path.size() - 1:
		target = target[key_path[i]]
	target[key_path[-1]] = value
	assert_object(SaveStore.from_saved(saved, _config)).is_null()


func test_an_unknown_item_on_sale_is_refused() -> void:
	var run: Run = _run()
	_enter_row_1(run, 0)
	var saved: Dictionary = run.to_dict()
	var shop: Dictionary = saved["floor"]["shop"][0]
	shop["offers"] = [99]
	assert_object(SaveStore.from_saved(saved, _config)).is_null()


func test_a_run_resumed_from_disk_at_a_shop_plays_on_alike() -> void:
	var run: Run = _run()
	_enter_row_1(run, 0)
	run.floor.shop.buy_tape()
	_assert_plays_on_alike(run, _resumed(run))


func test_a_run_resumed_from_disk_mid_rummage_plays_on_alike() -> void:
	var run: Run = _run()
	_enter_row_1(run, 2)
	run.floor.services.start_rummage()
	var resumed: Run = _resumed(run)
	assert_int(resumed.floor.services.rummage_offer().size()).is_greater(0)
	_assert_plays_on_alike(run, resumed)


func test_a_run_resumed_from_disk_at_a_sweep_plays_on_alike() -> void:
	var run: Run = _run()
	run.kit.add_item(ItemKind.Kind.SLEIGHT, ItemRules.from_config(_config))
	run.state.run_heat = 69.0
	run.floor.enter(run.floor.map.node_at(0, 1))
	run.floor.sit(0).table_heat.heat = 10.0
	run.floor.leave()
	var resumed: Run = _resumed(run)
	assert_int(resumed.floor.phase).is_equal(Floor.Phase.SWEEP)
	_assert_plays_on_alike(run, resumed)


func test_a_run_resumed_from_disk_after_the_marker_keeps_the_debt() -> void:
	var run: Run = _run()
	run.floor.enter(run.floor.map.node_at(0, 1))
	run.floor.sit(0).bankroll = 500
	run.floor.leave()
	assert_bool(run.state.marker_used).is_true()
	var resumed: Run = _resumed(run)
	assert_bool(resumed.state.marker_used).is_true()
	assert_int(resumed.floor.marker_loan).is_equal(run.floor.marker_loan)
	_assert_plays_on_alike(run, resumed)
