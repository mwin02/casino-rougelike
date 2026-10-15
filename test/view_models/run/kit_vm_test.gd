extends GdUnitTestSuite
## The kit screen (block U4, spec §2.4, §9) on floor 1: Shaded Lenses, Wax
## Pencil, Late Night and Permanent Ink in four of six slots. Late Night is
## 5 hands, Permanent Ink 2 charges a floor.

const PATH: String = "user://test_kit_vm.bin"

var _f: RunFixture
var _kit: ActionKit
var _vm: KitVM


func before_test() -> void:
	_f = RunFixture.new(PATH)
	_kit = _f.owner.run.kit
	var rules: ItemRules = ItemRules.from_config(_f.config)
	for item: ItemKind.Kind in [
		ItemKind.Kind.SHADED_LENSES, ItemKind.Kind.WAX_PENCIL, ItemKind.Kind.LATE_NIGHT,
		ItemKind.Kind.PERMANENT_INK,
	]:
		_kit.add_item(item, rules)
	_f.floor.give_late_hands()
	_vm = KitVM.new(_f.owner)


func after_test() -> void:
	_f.clear()


func test_the_slots_show_the_items_with_the_first_picked() -> void:
	assert_str(_vm.heading()).is_equal("FLOOR 1 · BETWEEN TABLES")
	assert_str(_vm.slots_text()).is_equal("4 / 6 SLOTS")
	assert_int(_vm.slots().size()).is_equal(6)
	assert_int(_vm.picked()).is_equal(0)
	assert_str(_vm.picked_item().name).is_equal("Shaded Lenses")
	assert_str(_vm.picked_item().effect).is_equal("Unlocks full reveal")


func test_an_empty_kit_has_nothing_picked() -> void:
	_f.clear()
	_f = RunFixture.new(PATH)
	var vm: KitVM = KitVM.new(_f.owner)
	assert_int(vm.picked()).is_equal(KitVM.NONE)
	assert_object(vm.picked_item()).is_null()
	assert_str(vm.discard_note()).is_empty()


func test_an_empty_slot_has_no_item_to_discard() -> void:
	_vm.pick(5)
	assert_object(_vm.picked_item()).is_null()
	_vm.press_discard()
	_vm.press_discard()
	assert_int(_kit.items.size()).is_equal(4)


func test_the_discard_note_says_what_goes_with_the_item(
	slot: int, note: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[0, "No refund. Full reveal locks again."],
		[1, "No refund. You lose its symbol."],
		[2, "No refund. Takes 5 hands off this floor."],
		[3, "No refund. Loses its 2 charges."],
	]
) -> void:
	_vm.pick(slot)
	assert_str(_vm.discard_note()).is_equal(note)


func test_an_item_that_just_goes_has_a_plain_note() -> void:
	_kit.add_item(ItemKind.Kind.SLEIGHT, ItemRules.from_config(_f.config))
	_vm.pick(4)
	assert_str(_vm.discard_note()).is_equal("No refund.")


func test_discarding_takes_two_presses() -> void:
	assert_str(_vm.discard_label()).is_equal("Discard")
	_vm.press_discard()
	assert_str(_vm.discard_label()).is_equal("Tap again to discard")
	assert_int(_kit.items.size()).is_equal(4)
	_vm.press_discard()
	assert_bool(_kit.has_item(ItemKind.Kind.SHADED_LENSES)).is_false()
	assert_str(_vm.discard_label()).is_equal("Discard")
	assert_str(_vm.picked_item().name).is_equal("Wax Pencil")
	assert_bool(_f.saved().kit.has_item(ItemKind.Kind.SHADED_LENSES)).is_false()


func test_picking_another_slot_disarms_the_discard() -> void:
	_vm.press_discard()
	_vm.pick(1)
	assert_str(_vm.discard_label()).is_equal("Discard")
	_vm.press_discard()
	assert_int(_kit.items.size()).is_equal(4)


func test_discarding_late_night_takes_its_hands_off_the_clock() -> void:
	var hands: int = _f.floor.clock.hands_left
	_vm.pick(2)
	_vm.press_discard()
	_vm.press_discard()
	assert_int(_f.floor.clock.hands_left).is_equal(hands - 5)


func test_discarding_the_last_item_leaves_nothing_picked() -> void:
	for i: int in 4:
		_vm.pick(0)
		_vm.press_discard()
		_vm.press_discard()
	assert_int(_kit.items.size()).is_equal(0)
	assert_int(_vm.picked()).is_equal(KitVM.NONE)


func test_the_actions_show_where_each_comes_from() -> void:
	var names: Array[String] = []
	var sources: Array[String] = []
	var locked: Array[bool] = []
	for row: KitAction in _vm.knowledge():
		names.append(row.name)
		sources.append(row.source)
		locked.append(row.locked)
	assert_array(names).contains_exactly(["Partial reveal", "Mark", "Full reveal", "Look ahead"])
	assert_array(sources).contains_exactly(
		["Starting kit", "Starting kit", "Shaded Lenses", "Needs Mirror Ring"]
	)
	assert_array(locked).contains_exactly([false, false, false, true])
	assert_str(_vm.manipulation()[1].name).is_equal("Nudge")
	assert_str(_vm.manipulation()[1].source).is_equal("Starting kit")
	assert_str(_vm.manipulation()[3].source).is_equal("Needs Cold Deck")


func test_the_symbols_count_the_cards_that_wear_them() -> void:
	var deck: Deck = _f.owner.run.game.deck
	for i: int in 4:
		deck.mark(deck.cards()[i].id, 0)
	var rows: Array[LegendRow] = _vm.symbols()
	assert_int(rows.size()).is_equal(3)
	assert_str(rows[0].name).is_equal("Star")
	assert_int(rows[0].count).is_equal(4)
	assert_int(rows[2].count).is_equal(0)


func test_what_else_is_held_is_listed() -> void:
	_kit.masking_tape = 2
	_kit.cold_seals = 1
	_kit.ink_charges = 1
	var rows: Array[PackedStringArray] = _vm.held()
	assert_array(Array(rows[0])).contains_exactly(["Masking Tape", "×2"])
	assert_array(Array(rows[1])).contains_exactly(["Cold Seal", "×1"])
	assert_array(Array(rows[2])).contains_exactly(["Ink charges", "1 / 2"])


func test_the_deck_opens_with_its_heat_floor() -> void:
	var deck: Deck = _f.owner.run.game.deck
	deck.mark(deck.cards()[0].id, 0)
	var view: DeckViewVM = _vm.deck()
	assert_int(view.cards().size()).is_equal(52)
	assert_str(view.heat_floor_text()).contains("1")
