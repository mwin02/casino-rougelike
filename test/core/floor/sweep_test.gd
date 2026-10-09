extends GdUnitTestSuite
## The security sweep (spec §7.6). Each time banked run heat crosses 70 from
## below, the floor stops until the player chooses what to lose: one owned
## item, or every mark of one symbol in the deck. With nothing to lose there
## is no sweep. Ejection at 100 comes first.

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new()
	_f.kit = ActionKit.starting()


func _give(item: ItemKind.Kind) -> void:
	_f.kit.add_item(item, ItemRules.from_config(_f.config))


## Leaves the first row's table with rollover run heat added (the stand-up share).
func _leave_first_table(floor: Floor, rollover: float) -> void:
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	var share: float = _f.config.get_float("run_heat", "stand_up_rollover")
	session.table_heat.heat = session.table_heat.heat_floor + rollover / share
	floor.leave()


## A floor whose first table takes run heat from 69 to 71.
func _crossed() -> Floor:
	_f.run.run_heat = 69.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 2.0)
	return floor


func _has(choices: Array[SweepChoice], expected: SweepChoice) -> bool:
	return choices.any(func(c: SweepChoice) -> bool: return c.same_as(expected))


func test_crossing_70_stops_the_floor_for_a_sweep() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	var floor: Floor = _crossed()
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)
	assert_array(floor.choices()).is_empty()


func test_the_sweep_offers_each_item_and_each_marked_symbol() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_give(ItemKind.Kind.POKER_FACE)
	var cards: Array[Card] = _f.deck.cards()
	_f.deck.mark(cards[0].id, 0)
	_f.deck.mark(cards[1].id, 0)
	var choices: Array[SweepChoice] = _crossed().sweep_choices()
	assert_array(choices).has_size(3)
	assert_bool(_has(choices, SweepChoice.of_item(ItemKind.Kind.SLEIGHT))).is_true()
	assert_bool(_has(choices, SweepChoice.of_item(ItemKind.Kind.POKER_FACE))).is_true()
	assert_bool(_has(choices, SweepChoice.of_symbol(0))).is_true()
	assert_bool(_has(choices, SweepChoice.of_symbol(1))).is_false()


func test_losing_an_item_takes_it_and_goes_on() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	var floor: Floor = _crossed()
	assert_bool(floor.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))).is_true()
	assert_bool(_f.kit.has_item(ItemKind.Kind.SLEIGHT)).is_false()
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_losing_a_symbol_clears_its_marks_and_lowers_the_heat_floor() -> void:
	var cards: Array[Card] = _f.deck.cards()
	_f.deck.mark(cards[0].id, 0)
	_f.deck.mark(cards[1].id, 0)
	_f.deck.mark(cards[2].id, 1)
	var rules: DeckRules = DeckRules.from_config(_f.config)
	var before: float = HeatFloor.of(_f.deck, _f.kit, rules)
	var floor: Floor = _crossed()
	assert_bool(floor.sweep(SweepChoice.of_symbol(0))).is_true()
	assert_int(_f.deck.card(cards[0].id).symbol).is_equal(Card.NO_SYMBOL)
	assert_int(_f.deck.card(cards[1].id).symbol).is_equal(Card.NO_SYMBOL)
	assert_int(_f.deck.card(cards[2].id).symbol).is_equal(1)
	assert_float(HeatFloor.of(_f.deck, _f.kit, rules)).is_less(before)
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_a_choice_not_offered_is_refused() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	var floor: Floor = _crossed()
	assert_bool(floor.sweep(SweepChoice.of_item(ItemKind.Kind.POKER_FACE))).is_false()
	assert_bool(floor.sweep(SweepChoice.of_symbol(0))).is_false()
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)


func test_nothing_to_lose_means_no_sweep() -> void:
	assert_int(_crossed().phase).is_equal(Floor.Phase.MAP)


func test_no_sweep_without_crossing() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_f.run.run_heat = 71.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 2.0)
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_crossing_again_sweeps_again() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_give(ItemKind.Kind.POKER_FACE)
	var floor: Floor = _crossed()
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))
	_f.run.run_heat = 69.0
	floor.enter(floor.map.node_at(1, 0))
	floor.leave()
	floor.enter(floor.map.node_at(2, 1))
	var session: TableSession = floor.sit(0)
	session.table_heat.heat = 10.0
	floor.leave()
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)


func test_after_the_last_row_the_sweep_leads_to_the_quota_check() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_f.run.run_heat = 69.0
	var floor: Floor = _f.floor_on([_f.tables(0, 1, [])])
	_leave_first_table(floor, 2.0)
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))
	assert_int(floor.phase).is_equal(Floor.Phase.QUOTA_CHECK)


func test_ejection_comes_before_the_sweep() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_f.run.run_heat = 69.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 31.0)
	assert_bool(_f.run.ejected).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)


func test_losing_another_item_keeps_permanent_inks_spent_charges() -> void:
	_give(ItemKind.Kind.PERMANENT_INK)
	_give(ItemKind.Kind.SLEIGHT)
	var floor: Floor = _crossed()
	_f.kit.ink_charges = 0
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))
	assert_int(_f.kit.ink_charges).is_equal(0)


func test_losing_permanent_ink_loses_its_charges() -> void:
	_give(ItemKind.Kind.PERMANENT_INK)
	var floor: Floor = _crossed()
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.PERMANENT_INK))
	assert_int(_f.kit.ink_charges).is_equal(0)


func test_losing_late_night_takes_its_hands_off_the_clock_at_once() -> void:
	_give(ItemKind.Kind.LATE_NIGHT)
	var floor: Floor = _crossed()
	var before: int = floor.clock.hands_left
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.LATE_NIGHT))
	var late: int = _f.config.get_int("items", "late_night_hands")
	assert_int(floor.clock.hands_left).is_equal(before - late)


## Leaves the first table broke (below floor 1's $1,000 minimum) with run
## heat taken from 69 to 71.
func _broke_and_crossed() -> Floor:
	_f.run.run_heat = 69.0
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	session.bankroll = 500
	session.table_heat.heat = 10.0
	floor.leave()
	return floor


func test_the_marker_fronts_money_before_the_sweep() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	var floor: Floor = _broke_and_crossed()
	assert_bool(_f.run.marker_used).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.SWEEP)
	floor.sweep(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_a_run_lost_to_going_broke_has_no_sweep() -> void:
	_give(ItemKind.Kind.SLEIGHT)
	_f.run.marker_used = true
	var floor: Floor = _broke_and_crossed()
	assert_bool(_f.run.lost).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)
