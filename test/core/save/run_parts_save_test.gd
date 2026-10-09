extends GdUnitTestSuite
## The parts of a run save on their own (block 14): the floor map with its
## tables, the kit, the run state, and shop stops with their deck services.
## Each comes back exactly as it was.

var _config: TuneConfig = TuneConfig.load_default()
var _rng: GameRng = GameRng.new(5)


func test_a_floor_map_round_trips_with_its_tables() -> void:
	var map: FloorMap = FloorMap.generate(_config, 2, _rng.stream(GameRng.Stream.FLOOR))
	map.nodes[0].tables[0].watched = true
	var restored: FloorMap = FloorMap.from_dict(map.to_dict())
	assert_dict(restored.to_dict()).is_equal(map.to_dict())
	assert_int(restored.row_count()).is_equal(map.row_count())
	assert_bool(restored.nodes[0].tables[0].watched).is_true()
	assert_int(restored.nodes[0].tables[0].table_max).is_equal(map.nodes[0].tables[0].table_max)


func test_a_kit_round_trips_its_items_charges_and_consumables() -> void:
	var rules: ItemRules = ItemRules.from_config(_config)
	var kit: ActionKit = ActionKit.starting()
	kit.add_item(ItemKind.Kind.PERMANENT_INK, rules)
	kit.add_item(ItemKind.Kind.WAX_PENCIL, rules)
	kit.ink_charges = 1
	kit.masking_tape = 3
	kit.cold_seals = 2
	var restored: ActionKit = ActionKit.from_dict(kit.to_dict(), rules)
	assert_array(restored.items).is_equal(kit.items)
	assert_array(restored.symbols).is_equal(kit.symbols)
	assert_int(restored.ink_charges).is_equal(1)
	assert_int(restored.masking_tape).is_equal(3)
	assert_int(restored.cold_seals).is_equal(2)


func test_a_run_state_round_trips() -> void:
	var state: RunState = RunState.new_run(_config)
	state.floor_number = 3
	state.bankroll = 1_234_567
	state.run_heat = 41.5
	state.heat_spent = 88.25
	state.extra_hands = 4
	state.carried_hands = 2
	state.marker_used = true
	state.quota_carry = 50_000
	assert_dict(RunState.from_dict(state.to_dict()).to_dict()).is_equal(state.to_dict())


func test_a_shop_round_trips_with_its_deck_services() -> void:
	var deck: Deck = Deck.standard(20)
	var kit: ActionKit = ActionKit.starting()
	var rules: ItemRules = ItemRules.from_config(_config)
	var pricing: ShopPricing = ShopPricing.from_config(_config, 1)
	var deck_rules: DeckRules = DeckRules.from_config(_config)
	var shop_rng: RandomNumberGenerator = _rng.stream(GameRng.Stream.SHOP)
	var services: DeckServices = DeckServices.new(
		deck_rules, deck, kit, pricing, 100_000, shop_rng
	)
	var shop: ShopStop = ShopStop.new(_config, pricing, 100_000, 5_000, 2, services)
	shop.stock(kit, rules, shop_rng)
	shop.buy_tape()
	var shown: Array[Card] = services.start_rummage()
	var restored_services: DeckServices = DeckServices.from_dict(
		services.to_dict(), deck_rules, deck, kit, pricing, shop_rng
	)
	var restored: ShopStop = ShopStop.from_dict(
		shop.to_dict(), _config, pricing, kit, rules, restored_services
	)
	assert_dict(restored.to_dict()).is_equal(shop.to_dict())
	assert_dict(restored_services.to_dict()).is_equal(services.to_dict())
	assert_int(restored.bankroll()).is_equal(shop.bankroll())
	assert_int(restored_services.rummage_offer().size()).is_equal(shown.size())
	# The reserve still holds, and items still sell into the kit.
	assert_int(restored_services.reserve).is_equal(5_000)
	var offer: ItemKind.Kind = restored.offers[0]
	assert_bool(restored.buy_item(offer)).is_true()
	assert_bool(kit.has_item(offer)).is_true()
