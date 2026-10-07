extends GdUnitTestSuite
## Items and consumables at a shop (spec §6.4, §9). Each shop draws a few
## items the player doesn't own, by rarity weight, no item twice, and keeps
## a small stock of Masking Tape and Cold Seals. Items cost their rarity's
## share of the quota and need a free slot; nothing is bought below the
## reserve. Default config: 3 offers weighted 3 / 2 / 1, tape stock 4 at 3%,
## seal stock 2 at 8%, items 5% / 10% / 18%.

const QUOTA: int = 100_000
const BANKROLL: int = 1_000_000

var _config: TuneConfig
var _pricing: ShopPricing
var _rules: ItemRules
var _kit: ActionKit


func before_test() -> void:
	_config = TuneConfig.load_default()
	_pricing = ShopPricing.new(QUOTA, 100, 100)
	_rules = ItemRules.from_config(_config)
	_kit = ActionKit.starting()


func _stop(bankroll: int = BANKROLL, reserve: int = 0, run_seed: int = 5) -> ShopStop:
	var stop: ShopStop = ShopStop.new(_config, _pricing, bankroll, reserve, 0)
	stop.stock(_kit, _rules, GameRng.new(run_seed).stream(GameRng.Stream.SHOP))
	return stop


func _rarities(items: Array[ItemKind.Kind]) -> Array[ItemKind.Rarity]:
	var result: Array[ItemKind.Rarity] = []
	for item: ItemKind.Kind in items:
		result.append(ItemKind.RARITY[item])
	return result


# Offers


func test_a_shop_offers_distinct_items() -> void:
	var offers: Array[ItemKind.Kind] = _stop().offers
	assert_int(offers.size()).is_equal(_rules.shop_item_offers)
	assert_int(_rules.shop_item_offers).is_equal(3)
	for item: ItemKind.Kind in offers:
		assert_int(offers.count(item)).is_equal(1)


func test_owned_items_are_never_offered() -> void:
	var owned: Array[ItemKind.Kind] = [
		ItemKind.Kind.SLEIGHT, ItemKind.Kind.QUIET_HANDS, ItemKind.Kind.COMP_SLIP,
		ItemKind.Kind.HOUSE_REGULAR, ItemKind.Kind.TELL_READER, ItemKind.Kind.LATE_NIGHT,
	]
	for item: ItemKind.Kind in owned:
		_kit.add_item(item, _rules)
	for run_seed: int in 20:
		for item: ItemKind.Kind in _stop(BANKROLL, 0, run_seed).offers:
			assert_bool(item in owned).is_false()


func test_the_weights_pick_the_rarity() -> void:
	_rules.offer_weights = [1, 0, 0]
	var commons: Array[ItemKind.Rarity] = _rarities(_stop().offers)
	assert_array(commons).not_contains([ItemKind.Rarity.UNCOMMON, ItemKind.Rarity.RARE])
	_rules.offer_weights = [0, 0, 1]
	var rares: Array[ItemKind.Rarity] = _rarities(_stop().offers)
	assert_array(rares).not_contains([ItemKind.Rarity.COMMON, ItemKind.Rarity.UNCOMMON])


func test_the_same_seed_offers_the_same_items() -> void:
	assert_array(_stop(BANKROLL, 0, 8).offers).is_equal(_stop(BANKROLL, 0, 8).offers)


func test_the_offers_never_run_past_the_items_left() -> void:
	_rules.offer_weights = [1, 0, 0]
	_rules.shop_item_offers = 10
	assert_int(_stop().offers.size()).is_equal(5)


# Buying items


func test_an_item_costs_its_raritys_share_of_the_quota() -> void:
	var stop: ShopStop = _stop()
	assert_int(stop.item_price(ItemKind.Kind.SLEIGHT)).is_equal(5_000)
	assert_int(stop.item_price(ItemKind.Kind.SIGNATURE)).is_equal(10_000)
	assert_int(stop.item_price(ItemKind.Kind.LATE_NIGHT)).is_equal(18_000)


func test_buying_an_offer_takes_it_into_a_slot() -> void:
	var stop: ShopStop = _stop()
	var item: ItemKind.Kind = stop.offers[0]
	assert_bool(stop.buy_item(item)).is_true()
	assert_bool(_kit.has_item(item)).is_true()
	assert_int(stop.bankroll()).is_equal(BANKROLL - stop.item_price(item))
	assert_bool(item in stop.offers).is_false()


func test_only_offered_items_can_be_bought() -> void:
	var stop: ShopStop = _stop()
	stop.offers = [ItemKind.Kind.SLEIGHT]
	assert_bool(stop.buy_item(ItemKind.Kind.SIGNATURE)).is_false()


func test_full_slots_refuse_an_item_without_charging() -> void:
	for item: ItemKind.Kind in ItemKind.UNLOCKS:
		_kit.add_item(item, _rules)
	_kit.add_item(ItemKind.Kind.WAX_PENCIL, _rules)
	var stop: ShopStop = _stop()
	assert_bool(stop.can_buy_item(stop.offers[0])).is_false()
	assert_bool(stop.buy_item(stop.offers[0])).is_false()
	assert_int(stop.bankroll()).is_equal(BANKROLL)


func test_an_item_is_never_bought_below_the_reserve() -> void:
	var stop: ShopStop = _stop(20_000, 15_000)
	stop.offers = [ItemKind.Kind.SIGNATURE]
	assert_bool(stop.buy_item(ItemKind.Kind.SIGNATURE)).is_false()
	stop.offers = [ItemKind.Kind.SLEIGHT]
	assert_bool(stop.buy_item(ItemKind.Kind.SLEIGHT)).is_true()


# Consumables


func test_masking_tape_sells_until_the_stock_runs_out() -> void:
	var stop: ShopStop = _stop()
	assert_int(stop.tape_price()).is_equal(3_000)
	for i: int in _rules.masking_tape_stock:
		assert_bool(stop.buy_tape()).is_true()
	assert_bool(stop.buy_tape()).is_false()
	assert_int(_kit.masking_tape).is_equal(4)
	assert_int(stop.bankroll()).is_equal(BANKROLL - 4 * 3_000)


func test_cold_seals_sell_until_the_stock_runs_out() -> void:
	var stop: ShopStop = _stop()
	assert_int(stop.seal_price()).is_equal(8_000)
	assert_bool(stop.buy_seal()).is_true()
	assert_bool(stop.buy_seal()).is_true()
	assert_bool(stop.buy_seal()).is_false()
	assert_int(_kit.cold_seals).is_equal(2)


func test_consumables_are_held_without_limit() -> void:
	_kit.masking_tape = 50
	assert_bool(_stop().buy_tape()).is_true()
	assert_int(_kit.masking_tape).is_equal(51)


# On the floor


func test_floor_shops_and_the_end_shop_sell_items() -> void:
	var floors: FloorFixture = FloorFixture.new(140_000)
	var floor: Floor = floors.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	assert_int(floor.shop.offers.size()).is_equal(_rules.shop_item_offers)
	assert_int(floor.shop.tape_stock).is_equal(_rules.masking_tape_stock)
	floor.leave()
	floor.cash_out()
	floor.check_quota()
	assert_int(floor.shop.offers.size()).is_equal(_rules.shop_item_offers)


func test_late_night_bought_mid_floor_adds_hands_now() -> void:
	var floors: FloorFixture = FloorFixture.new()
	var floor: Floor = floors.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 0))
	var hands: int = floor.clock.hands_left
	floor.shop.offers = [ItemKind.Kind.LATE_NIGHT]
	assert_bool(floor.shop.buy_item(ItemKind.Kind.LATE_NIGHT)).is_true()
	floor.leave()
	assert_int(floor.clock.hands_left).is_equal(hands + _rules.late_night_hands)
