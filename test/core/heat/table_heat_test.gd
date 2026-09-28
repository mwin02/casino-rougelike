extends GdUnitTestSuite
## A table session's heat (spec §1.6, §7.1, §7.2): hand heat lands at
## resolution, straight hands cool with a decay and never below the heat
## floor, tiers change, the Marked consequence fires once, and 90 backs the
## player off. Costs are the spec's centers. Card i has id i.

## Player 2 and 3, dealer 9 up and 7 in the hole (id 3).
const CARDS: Array[String] = ["2", "9", "3", "7", "4", "5", "6"]
const SEED: int = 4242

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()


func _table(heat_floor: float = 0.0, floor_number: int = 1, run_seed: int = SEED) -> TableHeat:
	var costs: TableCosts = TableCosts.centered(_f.heat_rules, GameKind.Kind.BLACKJACK)
	return TableHeat.start(_f.heat_rules, costs, heat_floor, floor_number, GameRng.new(run_seed))


## Plays a blackjack hand at the table: nudges the hole card if nudge, then
## resolves the hand's heat. Returns the lines it produced.
func _hand(table: TableHeat, nudge: bool = false) -> Array[HeatLine]:
	var rnd: BlackjackRound = _f.blackjack(CARDS)
	var actions: HandActions = _f.actions(rnd, table.start_hand(_f.session))
	if nudge:
		actions.nudge(3, 1)
	return table.finish_hand(actions.heat, rnd)


func _kinds(lines: Array[HeatLine]) -> Array[HeatLine.Kind]:
	var kinds: Array[HeatLine.Kind] = []
	for line: HeatLine in lines:
		kinds.append(line.kind)
	return kinds


func _line(lines: Array[HeatLine], kind: HeatLine.Kind) -> HeatLine:
	for line: HeatLine in lines:
		if line.kind == kind:
			return line
	return null


func _cool_rate() -> float:
	return _f.config.get_float("cooling", "cool_rate")


func _nudge() -> float:
	return _f.heat_rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.NUDGE)


func test_session_starts_at_the_heat_floor() -> void:
	assert_float(_table(12.0).heat).is_equal(12.0)


## §1.1: heat is applied at resolution, not as actions land.
func test_hand_heat_lands_at_resolution() -> void:
	var table: TableHeat = _table()
	var rnd: BlackjackRound = _f.blackjack(CARDS)
	var actions: HandActions = _f.actions(rnd, table.start_hand(_f.session))
	actions.nudge(3, 1)
	assert_float(table.heat).is_equal(0.0)
	var lines: Array[HeatLine] = table.finish_hand(actions.heat, rnd)
	assert_float(table.heat).is_equal_approx(_nudge(), 0.0001)
	assert_array(_kinds(lines)).contains_exactly([HeatLine.Kind.ACTION, HeatLine.Kind.MULTIPLIER])


## §7.1: the tier at the start of the hand prices it.
func test_hand_is_priced_by_the_tier_it_starts_in() -> void:
	var table: TableHeat = _table()
	table.heat = 30.0
	_hand(table, true)
	assert_float(table.heat).is_equal_approx(30.0 + _nudge() * 1.5, 0.0001)


## §1.6: cooling = heat × cool_rate × stake_factor(bet) × decay.
func test_straight_hand_at_max_bet_cools() -> void:
	_f.bet = ActionsFixture.TABLE_MAX
	var table: TableHeat = _table()
	table.heat = 50.0
	var lines: Array[HeatLine] = _hand(table)
	var cooling: float = 50.0 * _cool_rate()
	assert_float(table.heat).is_equal_approx(50.0 - cooling, 0.0001)
	assert_float(_line(lines, HeatLine.Kind.COOLING).amount).is_equal_approx(-cooling, 0.0001)


## §1.6: min-bet cooling is nearly worthless.
func test_min_bet_cools_far_less_than_max_bet() -> void:
	_f.bet = ActionsFixture.TABLE_MIN
	var table: TableHeat = _table()
	table.heat = 50.0
	_hand(table)
	var min_cooling: float = 50.0 - table.heat
	assert_float(min_cooling).is_greater(0.0)
	assert_float(min_cooling).is_less_equal(50.0 * _cool_rate() * 0.1 + 0.0001)


## §1.6: decay halves on each consecutive straight hand.
func test_cooling_decays_on_consecutive_straight_hands() -> void:
	_f.bet = ActionsFixture.TABLE_MAX
	var table: TableHeat = _table()
	table.heat = 50.0
	var expected: float = 50.0
	for decay: float in [1.0, 0.5, 0.25]:
		_hand(table)
		expected -= expected * _cool_rate() * decay
		assert_float(table.heat).is_equal_approx(expected, 0.0001)


## §1.6: any non-straight hand resets the decay, even one with only a bet
## change.
func test_bet_change_hand_resets_the_decay() -> void:
	_f.bet = ActionsFixture.TABLE_MAX / 2
	var table: TableHeat = _table()
	table.heat = 50.0
	_hand(table)
	var rnd: BlackjackRound = _f.blackjack(CARDS)
	var heat: HandHeat = table.start_hand(_f.session)
	rnd.proceed()
	rnd.adjust(rnd.total_bet() * 2)
	var lines: Array[HeatLine] = table.finish_hand(heat, rnd)
	assert_object(_line(lines, HeatLine.Kind.COOLING)).is_null()
	var before: float = table.heat
	_hand(table)
	var full_cooling: float = before * _cool_rate() * _stake_factor_mid()
	assert_float(table.heat).is_equal_approx(before - full_cooling, 0.0001)


func _stake_factor_mid() -> float:
	var position: float = inverse_lerp(
		float(ActionsFixture.TABLE_MIN), float(ActionsFixture.TABLE_MAX), ActionsFixture.TABLE_MAX / 2.0
	)
	return _f.heat_rules.stake_factor(position)


func test_action_hand_does_not_cool() -> void:
	_f.bet = ActionsFixture.TABLE_MAX
	var table: TableHeat = _table()
	table.heat = 20.0
	var lines: Array[HeatLine] = _hand(table, true)
	assert_object(_line(lines, HeatLine.Kind.COOLING)).is_null()


## §1.6, §4.2: cooling never takes heat below the table's heat floor.
func test_cooling_stops_at_the_heat_floor() -> void:
	_f.bet = ActionsFixture.TABLE_MAX
	var table: TableHeat = _table(44.0)
	table.heat = 45.0
	var lines: Array[HeatLine] = _hand(table)
	assert_float(table.heat).is_equal(44.0)
	assert_float(_line(lines, HeatLine.Kind.COOLING).amount).is_equal_approx(-1.0, 0.0001)
	for i: int in 5:
		_hand(table)
	assert_float(table.heat).is_equal(44.0)


func test_crossing_a_tier_adds_a_tier_line() -> void:
	var table: TableHeat = _table()
	table.heat = 25.0
	var line: HeatLine = _line(_hand(table, true), HeatLine.Kind.TIER)
	assert_int(line.tier).is_equal(HeatTier.Kind.WATCHED)
	assert_int(table.tier()).is_equal(HeatTier.Kind.WATCHED)


## §7.2 (with Pit Ledger, §9): the consequence is rolled at sit-down.
func test_consequence_is_rolled_at_sit_down() -> void:
	var a: TableHeat = _table(0.0, 3, 99)
	var b: TableHeat = _table(0.0, 3, 99)
	assert_int(a.consequence).is_equal(b.consequence)
	assert_bool(a.consequence_fired).is_false()


## §7.2: the consequence fires the first time 60 is crossed, once per session.
func test_marked_consequence_fires_once_per_session() -> void:
	var table: TableHeat = _table()
	table.heat = 55.0
	var first: HeatLine = _line(_hand(table, true), HeatLine.Kind.CONSEQUENCE)
	assert_object(first).is_not_null()
	assert_int(first.consequence).is_equal(table.consequence)
	assert_bool(table.consequence_fired).is_true()
	table.heat = 50.0
	assert_object(_line(_hand(table, true), HeatLine.Kind.CONSEQUENCE)).is_null()


## §7.2: a heat floor of 60 or more counts as crossing on the first hand,
## straight or not.
func test_consequence_fires_on_the_first_hand_above_a_high_floor() -> void:
	var table: TableHeat = _table(62.0)
	var line: HeatLine = _line(_hand(table), HeatLine.Kind.CONSEQUENCE)
	assert_object(line).is_not_null()
	assert_bool(table.consequence_fired).is_true()


## §7.2: P(house deck swap) is 20% on floor 1 and 80% on floor 5.
func test_house_swap_chance_follows_the_floor() -> void:
	var swaps: Array[int] = [0, 0]
	for run_seed: int in 1000:
		for i: int in 2:
			var floor_number: int = 1 if i == 0 else 5
			if _table(0.0, floor_number, run_seed).consequence == MarkedConsequence.Kind.HOUSE_DECK_SWAP:
				swaps[i] += 1
	assert_int(swaps[0]).is_between(150, 250)
	assert_int(swaps[1]).is_between(750, 850)


## §7.2: a new dealer redraws the table's cost rolls.
func test_new_dealer_rerolls_the_costs() -> void:
	var run_seed: int = 0
	while _table(0.0, 1, run_seed).consequence != MarkedConsequence.Kind.NEW_DEALER:
		run_seed += 1
	var table: TableHeat = _table(0.0, 1, run_seed)
	var before: TableCosts = table.costs
	table.heat = 55.0
	_hand(table, true)
	assert_object(table.costs).is_not_same(before)
	assert_float(table.costs.base_cost(ActionKind.Kind.SWITCH, 0)).is_not_equal(
		before.base_cost(ActionKind.Kind.SWITCH, 0)
	)


func test_house_deck_swap_keeps_the_costs() -> void:
	var run_seed: int = 0
	while _table(0.0, 5, run_seed).consequence != MarkedConsequence.Kind.HOUSE_DECK_SWAP:
		run_seed += 1
	var table: TableHeat = _table(0.0, 5, run_seed)
	var before: TableCosts = table.costs
	table.heat = 55.0
	_hand(table, true)
	assert_object(table.costs).is_same(before)


## §7.1: 90 backs the player off after the current hand.
func test_backed_off_at_90() -> void:
	var table: TableHeat = _table()
	table.heat = 85.0
	var lines: Array[HeatLine] = _hand(table, true)
	assert_bool(table.backed_off).is_true()
	assert_int(table.tier()).is_equal(HeatTier.Kind.BACKED_OFF)
	assert_object(_line(lines, HeatLine.Kind.BACKED_OFF)).is_not_null()


func test_below_90_is_not_backed_off() -> void:
	var table: TableHeat = _table()
	table.heat = 65.0
	_hand(table, true)
	assert_float(table.heat).is_less(90.0)
	assert_bool(table.backed_off).is_false()
