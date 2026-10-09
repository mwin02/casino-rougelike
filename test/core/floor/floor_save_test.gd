extends GdUnitTestSuite
## A floor saves off a table seat and comes back as it was (block 14): on
## the map, at a shop, at deck services with a Rummage open, at a sweep, and
## in the end shop. The restored floor plays on from there. The run, deck,
## kit and RNG save with the run.

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new()


func _restored(floor: Floor) -> Floor:
	var restored: Floor = Floor.from_dict(
		floor.to_dict(), _f.config, _f.run, _f.deck, _f.layer, _f.kit, _f.rng
	)
	assert_dict(restored.to_dict()).is_equal(floor.to_dict())
	return restored


func test_a_floor_on_the_map_comes_back_where_it_was() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	FloorFixture.play(floor, 2)
	floor.leave()
	var restored: Floor = _restored(floor)
	assert_object(restored.current).is_same(restored.map.node_at(0, 1))
	assert_int(restored.clock.hands_left).is_equal(floor.clock.hands_left)
	assert_bool(restored.enter(restored.map.node_at(1, 0))).is_true()


func test_a_floor_at_a_shop_comes_back_with_its_stock() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	floor.shop.buy_tape()
	var restored: Floor = _restored(floor)
	assert_array(restored.shop.offers).is_equal(floor.shop.offers)
	assert_int(restored.shop.tape_stock).is_equal(floor.shop.tape_stock)
	assert_bool(restored.shop.buy_extra_hand()).is_true()
	assert_bool(restored.leave()).is_true()
	assert_int(restored.extra_hands_bought).is_equal(1)


func test_a_floor_mid_rummage_comes_back_with_the_cards_shown() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 2))
	var shown: Array[Card] = floor.services.start_rummage()
	var restored: Floor = _restored(floor)
	var again: Array[Card] = restored.services.rummage_offer()
	assert_int(again.size()).is_equal(shown.size())
	for i: int in shown.size():
		assert_int(again[i].id).is_equal(shown[i].id)
	var card: Card = again[0]
	var rank: int = card.rank + 1 if card.rank < 13 else card.rank - 1
	assert_bool(restored.services.rummage(card.id, rank, card.suit)).is_true()


func test_a_floor_at_a_sweep_comes_back_to_it() -> void:
	_f.kit = ActionKit.starting()
	_f.kit.add_item(ItemKind.Kind.SLEIGHT, ItemRules.from_config(_f.config))
	_f.run.run_heat = 69.0
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.sit(0).table_heat.heat = 10.0
	floor.leave()
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)
	var restored: Floor = _restored(floor)
	assert_bool(restored.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))).is_true()
	assert_int(restored.phase).is_equal(Floor.Phase.MAP)


func test_a_floor_in_the_end_shop_comes_back_with_its_reserve() -> void:
	_f.run.bankroll = 200_000
	var floor: Floor = _f.three_rows()
	floor.cash_out()
	floor.check_quota()
	floor.shop.services.start_rummage()
	var restored: Floor = _restored(floor)
	assert_int(restored.phase).is_equal(Floor.Phase.END_SHOP)
	assert_int(restored.next_floor_min).is_equal(floor.next_floor_min)
	assert_int(restored.shop.services.reserve).is_equal(floor.next_floor_min)
	assert_int(restored.shop.services.rummage_offer().size()).is_greater(0)
	assert_bool(restored.finish()).is_true()


func test_a_restored_floor_keeps_its_watched_tables_and_draws_none() -> void:
	_f.run.run_heat = 40.0
	var floor: Floor = _f.three_rows()
	var stream: RandomNumberGenerator = _f.rng.stream(GameRng.Stream.FLOOR)
	var state: int = stream.state
	var restored: Floor = _restored(floor)
	assert_int(stream.state).is_equal(state)
	var watched: int = 0
	for node: MapNode in restored.map.nodes:
		for table: Table in node.tables:
			if table.watched:
				watched += 1
	assert_int(watched).is_equal(1)


func test_a_restored_floor_keeps_permanent_inks_spent_charges() -> void:
	_f.kit = ActionKit.starting()
	_f.kit.add_item(ItemKind.Kind.PERMANENT_INK, ItemRules.from_config(_f.config))
	var floor: Floor = _f.three_rows()
	_f.kit.ink_charges = 0
	_restored(floor)
	assert_int(_f.kit.ink_charges).is_equal(0)


func test_the_floors_side_bet_manipulations_survive_a_save() -> void:
	var floor: Floor = _f.three_rows()
	floor.side_bet_manipulations = 3
	assert_int(_restored(floor).side_bet_manipulations).is_equal(3)
