extends GdUnitTestSuite
## The security sweep on screen (block U4, spec §7.6): the kit holds Wax
## Pencil, Late Night and Permanent Ink; seven cards wear a star and one a
## moon. Late Night is 5 hands and Permanent Ink 2 charges a floor.

const PATH: String = "user://test_sweep_vm.bin"

var _f: RunFixture
var _vm: SweepVM


func before_test() -> void:
	_f = RunFixture.new(PATH)
	var run: Run = _f.owner.run
	var rules: ItemRules = ItemRules.from_config(_f.config)
	for item: ItemKind.Kind in [
		ItemKind.Kind.WAX_PENCIL, ItemKind.Kind.LATE_NIGHT, ItemKind.Kind.PERMANENT_INK,
	]:
		run.kit.add_item(item, rules)
	run.kit.refill_ink()
	_f.floor.give_late_hands()
	var cards: Array[Card] = run.game.deck.cards()
	for i: int in 7:
		run.game.deck.mark(cards[i].id, 0)
	run.game.deck.mark(cards[20].id, 1)
	_f.floor.phase = Floor.Phase.SWEEP
	_vm = SweepVM.new(_f.owner)


func after_test() -> void:
	_f.clear()


func _item(kind: ItemKind.Kind) -> SweepRow:
	for row: SweepRow in _vm.items():
		if row.choice.item == kind:
			return row
	return null


func test_the_screen_is_the_sweep() -> void:
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.SWEEP)


func test_each_owned_item_can_be_lost() -> void:
	var names: Array[String] = []
	for row: SweepRow in _vm.items():
		names.append(row.name)
	assert_array(names).contains_exactly(["Wax Pencil", "Late Night", "Permanent Ink"])
	assert_str(_item(ItemKind.Kind.WAX_PENCIL).detail).is_equal("+1 symbol")
	assert_str(_vm.slots_text()).is_equal("3 / 6 SLOTS")
	assert_int(_vm.empty_slots()).is_equal(3)


func test_an_item_whose_loss_costs_more_says_so() -> void:
	assert_str(_item(ItemKind.Kind.WAX_PENCIL).warning).is_empty()
	assert_str(_item(ItemKind.Kind.LATE_NIGHT).warning).is_equal("Takes 5 hands off this floor")
	assert_str(_item(ItemKind.Kind.PERMANENT_INK).warning).is_equal("Loses its 2 charges")


func test_spent_ink_has_no_charges_to_lose() -> void:
	_f.owner.run.kit.ink_charges = 1
	assert_str(_item(ItemKind.Kind.PERMANENT_INK).warning).is_equal("Loses its 1 charge")
	_f.owner.run.kit.ink_charges = 0
	assert_str(_item(ItemKind.Kind.PERMANENT_INK).warning).is_empty()


func test_each_marked_symbol_can_be_cleared() -> void:
	var rows: Array[SweepRow] = _vm.symbols()
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0].name).is_equal("Star")
	assert_str(rows[0].detail).is_equal("7 marked cards")
	assert_int(rows[0].cards.size()).is_equal(3)
	assert_int(rows[0].cards[0].symbol).is_equal(0)
	assert_str(rows[1].name).is_equal("Moon")
	assert_str(rows[1].detail).is_equal("1 marked card")
	assert_int(rows[1].cards.size()).is_equal(1)


func test_nothing_is_picked_at_first() -> void:
	assert_bool(_vm.can_confirm()).is_false()
	assert_str(_vm.confirm_text()).is_equal("Choose what to lose")
	assert_str(_vm.note()).is_equal("One item, or every mark of one symbol.")


func test_picking_an_item_says_what_goes() -> void:
	_vm.pick(_item(ItemKind.Kind.LATE_NIGHT).choice)
	assert_bool(_item(ItemKind.Kind.LATE_NIGHT).picked).is_true()
	assert_bool(_item(ItemKind.Kind.WAX_PENCIL).picked).is_false()
	assert_bool(_vm.can_confirm()).is_true()
	assert_str(_vm.confirm_text()).is_equal("Lose Late Night")
	assert_str(_vm.note()).is_equal("You lose Late Night. Takes 5 hands off this floor.")


func test_picking_a_symbol_says_what_goes() -> void:
	_vm.pick(_vm.symbols()[0].choice)
	assert_bool(_vm.symbols()[0].picked).is_true()
	assert_bool(_vm.symbols()[1].picked).is_false()
	assert_str(_vm.confirm_text()).is_equal("Lose star marks")
	assert_str(_vm.note()).is_equal(
		"7 cards lose their star. Your heat floor drops from the next session."
	)
	_vm.pick(_vm.symbols()[1].choice)
	assert_str(_vm.note()).is_equal(
		"1 card loses its moon. Your heat floor drops from the next session."
	)


func test_confirming_with_no_pick_does_nothing() -> void:
	_vm.confirm()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.SWEEP)


func test_losing_an_item_frees_its_slot_and_the_floor_goes_on() -> void:
	var hands: int = _f.floor.clock.hands_left
	_vm.pick(_item(ItemKind.Kind.LATE_NIGHT).choice)
	_vm.confirm()
	assert_bool(_f.owner.run.kit.has_item(ItemKind.Kind.LATE_NIGHT)).is_false()
	assert_int(_f.floor.clock.hands_left).is_equal(hands - 5)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_bool(_f.saved().kit.has_item(ItemKind.Kind.LATE_NIGHT)).is_false()


func test_clearing_a_symbol_takes_every_mark_of_it() -> void:
	_vm.pick(_vm.symbols()[0].choice)
	_vm.confirm()
	assert_int(_f.owner.run.game.deck.marked_count()).is_equal(1)
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
