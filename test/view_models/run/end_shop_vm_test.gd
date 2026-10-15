extends GdUnitTestSuite
## The end of a floor on screen (block U4, spec §6.2, §6.5, §11), after
## floor 1 (quota $140,000) on Medium: floor 2's quota is $560,000 and its
## low-stakes minimum, the end shop's reserve, $4,000.

const PATH: String = "user://test_end_shop_vm.bin"

var _f: RunFixture
var _vm: EndShopVM


func after_test() -> void:
	_f.clear()


func _open(bankroll: int) -> void:
	_f = RunFixture.new(PATH, bankroll)
	_f.enter_end_shop()
	_vm = EndShopVM.new(_f.owner)


func test_the_screen_is_the_end_shop() -> void:
	_open(168_400)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.END_SHOP)


func test_a_met_quota_reads_as_passed() -> void:
	_open(168_400)
	var check: QuotaStrip = _vm.check()
	assert_str(check.heading).is_equal("FLOOR 1 · QUOTA CHECK")
	assert_str(check.title).is_equal("Quota met")
	assert_bool(check.short).is_false()
	assert_str(check.bankroll_text).is_equal("$168,400")
	assert_str(check.quota_text).is_equal("/ $140,000")
	assert_str(check.lead).is_equal("Passed")
	assert_str(check.detail).is_equal("$28,400 over the quota · elevator key card awarded")


func test_a_short_check_shows_the_marker_its_loan_and_the_next_quota() -> void:
	_open(128_500)
	var check: QuotaStrip = _vm.check()
	assert_str(check.title).is_equal("Short, marker covered it")
	assert_bool(check.short).is_true()
	assert_str(check.bankroll_text).is_equal("$128,500")
	assert_str(check.lead).is_equal("Marker: house fronted $11,500")
	assert_str(check.detail).is_equal(
		"repay $14,375 (loan + 25%) on floor 2 · floor 2 quota $574,375"
	)


func test_a_marker_called_mid_floor_still_shows_on_a_met_quota() -> void:
	_f = RunFixture.new(PATH, 150_000)
	_f.floor.marker_loan = 20_000
	_f.owner.run.state.marker_used = true
	_f.enter_end_shop()
	var check: QuotaStrip = EndShopVM.new(_f.owner).check()
	assert_str(check.title).is_equal("Quota met")
	assert_bool(check.short).is_false()
	assert_str(check.lead).is_equal("Marker: house fronted $20,000")
	assert_str(check.detail).is_equal(
		"repay $25,000 (loan + 25%) on floor 2 · floor 2 quota $585,000"
	)


func test_the_bankroll_shows_the_reserve_and_what_is_left_to_spend() -> void:
	_open(168_400)
	var money: ReserveMoney = _vm.money()
	assert_str(money.bankroll_text()).is_equal("$168,400")
	assert_str(money.reserve_text()).is_equal("Floor $4,000")
	assert_str(money.spend_text()).is_equal("$164,400")
	assert_float(money.bankroll_share()).is_equal(1.0)
	assert_float(money.reserve_share()).is_equal_approx(4_000.0 / 168_400.0, 0.0001)
	assert_float(money.quota_share()).is_equal_approx(140_000.0 / 168_400.0, 0.0001)


func test_the_marker_s_money_is_in_the_bankroll() -> void:
	_open(128_500)
	assert_str(_vm.money().bankroll_text()).is_equal("$140,000")
	assert_float(_vm.money().quota_share()).is_equal(1.0)


func test_buying_spends_the_bankroll_down() -> void:
	_open(168_400)
	_vm.shop().buy_consumable(ConsumableRow.Kind.TAPE)
	var money: ReserveMoney = _vm.money()
	assert_str(money.bankroll_text()).is_equal("$164,200")
	assert_str(money.spend_text()).is_equal("$160,200")
	assert_float(money.bankroll_share()).is_equal_approx(164_200.0 / 168_400.0, 0.0001)
	assert_array(_vm.held_values()).contains_exactly(["1", "0", "+0"])


func test_a_purchase_that_would_break_the_reserve_reads_over_floor() -> void:
	_open(168_400)
	# $4,000 reserve + $4,200 tape - $1.
	_f.floor.shop.services.bankroll = 8_199
	var tape: ConsumableRow = _vm.shop().consumables()[0]
	assert_bool(tape.can_buy).is_false()
	assert_str(tape.verb).is_equal("Over floor")
	_f.floor.shop.services.bankroll = 8_200
	assert_bool(_vm.shop().consumables()[0].can_buy).is_true()
	# An extra hand is $2,800.
	_f.floor.shop.services.bankroll = 6_799
	assert_str(_vm.shop().hands().verb).is_equal("Over floor")


func test_there_is_a_tab_for_each_part_of_the_shop() -> void:
	_open(168_400)
	var labels: Array[String] = []
	for tab: Choice in _vm.tabs():
		labels.append(tab.label)
	assert_array(labels).contains_exactly(["Items", "Consumables", "Hands", "Services"])
	assert_bool(_vm.tabs()[0].selected).is_true()
	_vm.pick_tab(EndShopVM.Tab.SERVICES)
	assert_int(_vm.tab).is_equal(EndShopVM.Tab.SERVICES)
	assert_bool(_vm.tabs()[3].selected).is_true()
	assert_bool(_vm.tabs()[0].selected).is_false()


func test_the_services_tab_works_the_end_shop_s_deck_services() -> void:
	_open(168_400)
	var before: int = _f.owner.run.game.deck.size()
	var services: ServicesVM = _vm.services()
	services.select(DeckServices.Service.REMOVE)
	services.pick_card(services.cards()[0].id)
	services.confirm()
	assert_int(_f.owner.run.game.deck.size()).is_equal(before - 1)
	assert_str(_vm.money().bankroll_text()).is_equal("$161,400")


func test_extra_hands_bought_show_for_the_next_floor() -> void:
	_open(168_400)
	_vm.shop().buy_hand()
	_vm.shop().buy_hand()
	assert_array(_vm.held_labels()).contains_exactly(["TAPE", "SEALS", "FLOOR 2 HANDS"])
	assert_array(_vm.held_values()).contains_exactly(["0", "0", "+2"])


func test_the_elevator_button_names_the_next_floor_and_its_quota() -> void:
	_open(168_400)
	assert_str(_vm.elevator_text()).is_equal("Take the elevator")
	assert_str(_vm.next_text()).is_equal("TO FLOOR 2 · QUOTA $560,000")


func test_taking_the_elevator_banks_the_shop_and_leaves_the_floor() -> void:
	_open(168_400)
	_vm.shop().buy_hand()
	_vm.take_elevator()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.ELEVATOR)
	assert_int(_f.owner.run.state.bankroll).is_equal(165_600)
	assert_int(_f.owner.run.state.extra_hands).is_equal(1)
	assert_int(_f.saved().state.floor_number).is_equal(2)


func test_a_purchase_is_saved() -> void:
	_open(168_400)
	_vm.shop().buy_consumable(ConsumableRow.Kind.SEAL)
	var saved: Run = _f.saved()
	assert_int(saved.floor.shop.bankroll()).is_equal(157_200)
	assert_int(saved.kit.cold_seals).is_equal(1)
