extends GdUnitTestSuite
## A mid-floor shop on screen (block U4, spec §6.4, §9), on floor 1 (quota
## $140,000) with $96,500: Pit Ledger, Poker Face and House Regular on the
## shelf. Common 5%, uncommon 10% of the quota; tape 3%, a seal 8%, an extra
## hand 2%.

const PATH: String = "user://test_shop_vm.bin"

var _f: RunFixture
var _shop: ShopStop
var _vm: ShopVM


func before_test() -> void:
	_f = RunFixture.new(PATH, 96_500)
	_f.enter_shop()
	_shop = _f.floor.shop
	_shop.offers = [
		ItemKind.Kind.PIT_LEDGER, ItemKind.Kind.POKER_FACE, ItemKind.Kind.HOUSE_REGULAR,
	]
	_vm = ShopVM.new(_f.owner)


func after_test() -> void:
	_f.clear()


func _row(item: ItemKind.Kind) -> ShopItemRow:
	for row: ShopItemRow in _vm.items():
		if row.info.kind == item:
			return row
	return null


func _fill_slots() -> void:
	var rules: ItemRules = ItemRules.from_config(_f.config)
	for item: ItemKind.Kind in [
		ItemKind.Kind.SLEIGHT, ItemKind.Kind.SIGNATURE, ItemKind.Kind.COMP_SLIP,
		ItemKind.Kind.LATE_NIGHT, ItemKind.Kind.DEEP_READ, ItemKind.Kind.QUIET_HANDS,
	]:
		_f.owner.run.kit.add_item(item, rules)


func test_the_screen_is_the_shop() -> void:
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.SHOP)
	assert_str(_vm.prices_text()).is_equal("FLOOR 1 PRICES")


func test_the_shelf_prices_each_item_by_its_rarity() -> void:
	var names: Array[String] = []
	var prices: Array[String] = []
	for row: ShopItemRow in _vm.items():
		names.append(row.info.name)
		prices.append(row.price_text)
	assert_array(names).contains_exactly(["Pit Ledger", "Poker Face", "House Regular"])
	assert_array(prices).contains_exactly(["$14,000", "$14,000", "$7,000"])
	assert_int(_row(ItemKind.Kind.POKER_FACE).price).is_equal(
		_shop.item_price(ItemKind.Kind.POKER_FACE)
	)


func test_each_item_shows_the_gap_buying_it_would_leave() -> void:
	assert_str(_vm.money().gap_text()).is_equal("$43,500 short")
	assert_str(_row(ItemKind.Kind.POKER_FACE).gap_after_text).is_equal("$57,500")
	assert_str(_row(ItemKind.Kind.HOUSE_REGULAR).gap_after_text).is_equal("$50,500")


func test_the_bankroll_shows_against_the_quota() -> void:
	assert_str(_vm.money().bankroll_text()).is_equal("$96,500")
	assert_str(_vm.money().quota_text()).is_equal("Quota $140,000")
	assert_bool(_vm.money().at_quota()).is_false()
	assert_str(_vm.money().note()).is_equal(ShopMoney.UNDER_QUOTA)


func test_the_first_item_is_picked_and_previewed() -> void:
	assert_str(_vm.preview_title()).is_equal("IF YOU BUY PIT LEDGER")
	_vm.pick(ItemKind.Kind.POKER_FACE)
	assert_bool(_row(ItemKind.Kind.POKER_FACE).picked).is_true()
	assert_bool(_row(ItemKind.Kind.PIT_LEDGER).picked).is_false()
	assert_str(_vm.preview_title()).is_equal("IF YOU BUY POKER FACE")
	assert_str(_vm.preview_bankroll_text()).is_equal("$82,500")
	assert_str(_vm.preview_gap_text()).is_equal("$57,500")
	var shares: Vector2 = _vm.preview_shares()
	assert_float(shares.x).is_equal_approx(82_500.0 / 140_000.0, 0.0001)
	assert_float(shares.y).is_equal_approx(14_000.0 / 140_000.0, 0.0001)


func test_picking_an_item_not_on_the_shelf_changes_nothing() -> void:
	_vm.pick(ItemKind.Kind.LATE_NIGHT)
	assert_str(_vm.preview_title()).is_equal("IF YOU BUY PIT LEDGER")


func test_buying_an_item_pays_fills_a_slot_and_saves() -> void:
	assert_str(_vm.slots_text()).is_equal("0 / 6 SLOTS")
	assert_bool(_row(ItemKind.Kind.POKER_FACE).can_buy).is_true()
	assert_str(_row(ItemKind.Kind.POKER_FACE).verb).is_equal("Buy")
	_vm.buy_item(ItemKind.Kind.POKER_FACE)
	assert_str(_vm.money().bankroll_text()).is_equal("$82,500")
	assert_object(_row(ItemKind.Kind.POKER_FACE)).is_null()
	assert_str(_vm.slots_text()).is_equal("1 / 6 SLOTS")
	var slots: Array[ItemSlot] = _vm.slots()
	assert_int(slots.size()).is_equal(6)
	assert_bool(slots[0].filled).is_true()
	assert_str(slots[0].info.name).is_equal("Poker Face")
	assert_bool(slots[1].filled).is_false()
	assert_bool(_f.saved().kit.has_item(ItemKind.Kind.POKER_FACE)).is_true()
	assert_int(_f.saved().floor.shop.bankroll()).is_equal(82_500)
	assert_str(_vm.preview_title()).is_equal("IF YOU BUY PIT LEDGER")


func test_an_item_needs_a_free_slot() -> void:
	_fill_slots()
	var row: ShopItemRow = _row(ItemKind.Kind.POKER_FACE)
	assert_bool(row.can_buy).is_false()
	assert_str(row.verb).is_equal("No free slot")
	assert_str(_vm.slots_text()).is_equal("6 / 6 SLOTS")
	_vm.buy_item(ItemKind.Kind.POKER_FACE)
	assert_str(_vm.money().bankroll_text()).is_equal("$96,500")


func test_an_item_the_bankroll_cant_cover_says_so() -> void:
	_f = RunFixture.new(PATH, 10_000)
	_f.enter_shop()
	_f.floor.shop.offers = [ItemKind.Kind.POKER_FACE, ItemKind.Kind.HOUSE_REGULAR]
	_vm = ShopVM.new(_f.owner)
	assert_str(_row(ItemKind.Kind.POKER_FACE).verb).is_equal("Can't afford")
	assert_bool(_row(ItemKind.Kind.HOUSE_REGULAR).can_buy).is_true()


func test_consumables_show_price_stock_and_what_is_held() -> void:
	var rows: Array[ConsumableRow] = _vm.consumables()
	assert_str(rows[0].name).is_equal("Masking Tape")
	assert_str(rows[0].price_text).is_equal("$4,200")
	assert_str(rows[0].stock_text).is_equal("4 / 4")
	assert_int(rows[0].held).is_equal(0)
	assert_str(rows[1].name).is_equal("Cold Seal")
	assert_str(rows[1].price_text).is_equal("$11,200")
	assert_str(rows[1].stock_text).is_equal("2 / 2")


func test_buying_tape_takes_it_from_stock_into_the_kit() -> void:
	_vm.buy_consumable(ConsumableRow.Kind.TAPE)
	var tape: ConsumableRow = _vm.consumables()[0]
	assert_str(tape.stock_text).is_equal("3 / 4")
	assert_int(tape.held).is_equal(1)
	assert_int(_f.owner.run.kit.masking_tape).is_equal(1)
	assert_str(_vm.money().bankroll_text()).is_equal("$92,300")
	assert_int(_f.saved().kit.masking_tape).is_equal(1)


func test_a_consumable_sells_out() -> void:
	_vm.buy_consumable(ConsumableRow.Kind.SEAL)
	_vm.buy_consumable(ConsumableRow.Kind.SEAL)
	var seal: ConsumableRow = _vm.consumables()[1]
	assert_bool(seal.can_buy).is_false()
	assert_str(seal.verb).is_equal("Sold out")
	assert_int(_vm.consumables()[1].held).is_equal(2)
	_vm.buy_consumable(ConsumableRow.Kind.SEAL)
	assert_int(_vm.consumables()[1].held).is_equal(2)


func test_extra_hands_are_sold_up_to_the_cap() -> void:
	var cap: int = _f.config.get_int("clock", "extra_hands_cap")
	assert_str(_vm.hands().title).is_equal("Extra hands for floor 2")
	assert_str(_vm.hands().price_text).is_equal("$2,800")
	assert_str(_vm.hands().text()).is_equal("+0 of %d bought" % cap)
	_vm.buy_hand()
	assert_str(_vm.hands().text()).is_equal("+1 of %d bought" % cap)
	assert_int(_vm.hands().bought).is_equal(1)
	assert_str(_vm.money().bankroll_text()).is_equal("$93,700")
	for i: int in cap:
		_vm.buy_hand()
	assert_int(_vm.hands().bought).is_equal(cap)
	assert_bool(_vm.hands().can_buy).is_false()
	assert_str(_vm.hands().verb).is_equal("Sold out")


func test_late_night_adds_its_hands_to_the_clock_at_once() -> void:
	_shop.offers = [ItemKind.Kind.LATE_NIGHT]
	_vm = ShopVM.new(_f.owner)
	var hands: int = _f.floor.clock.hands_left
	var late: int = _f.config.get_int("items", "late_night_hands")
	_vm.buy_item(ItemKind.Kind.LATE_NIGHT)
	assert_int(_f.floor.clock.hands_left).is_equal(hands + late)
	assert_str(_vm.hud().hands_left_text()).is_equal("%d hands left" % (hands + late))
	_vm.leave()
	assert_int(_f.floor.clock.hands_left).is_equal(hands + late)


func test_the_last_floors_shop_sells_no_extra_hands() -> void:
	_f = RunFixture.new(PATH, 96_500)
	_f.owner.run.state.floor_number = TuneSchema.FLOORS
	_f.enter_shop()
	_vm = ShopVM.new(_f.owner)
	var hands: ShopHands = _vm.hands()
	assert_bool(hands.can_buy).is_false()
	assert_str(hands.verb).is_equal("Last floor")
	assert_str(hands.text()).is_empty()
	_vm.buy_hand()
	assert_int(_f.floor.shop.extra_hands).is_equal(0)
	assert_str(_vm.money().bankroll_text()).is_equal("$96,500")
	assert_bool(_f.saved().floor.shop.can_buy_extra_hand()).is_false()


func test_leaving_banks_the_spending_and_goes_back_to_the_map() -> void:
	_vm.buy_item(ItemKind.Kind.HOUSE_REGULAR)
	_vm.buy_hand()
	_vm.leave()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_f.owner.run.state.bankroll).is_equal(96_500 - 7_000 - 2_800)
	assert_int(_f.floor.extra_hands_bought).is_equal(1)


func test_over_the_quota_the_note_changes() -> void:
	_f = RunFixture.new(PATH, 150_000)
	_f.enter_shop()
	_vm = ShopVM.new(_f.owner)
	assert_bool(_vm.money().at_quota()).is_true()
	assert_str(_vm.money().gap_text()).is_equal("Quota reached")
	assert_str(_vm.money().note()).is_equal(ShopMoney.OVER_QUOTA)
