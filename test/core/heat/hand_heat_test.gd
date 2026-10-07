extends GdUnitTestSuite
## One hand's heat (spec §1.1, §1.5, §7.1): each action is charged as it lands.
## At resolution each adjust and side switch adds the bet-change base, then
## the multiplier applies to the whole. Doubles, splits and insurance add no
## base. Costs are the spec's centers. Card i has id i.

## Player 2 and 3, dealer 9 up and 7 in the hole (id 3); hits deal 4, 5, 6.
const HITS: Array[String] = ["2", "9", "3", "7", "4", "5", "6"]

var _f: ActionsFixture


func before_test() -> void:
	_f = ActionsFixture.new()
	# A different base per game, so each hand is seen to pay its own game's.
	_f.heat_rules.bet_change_bases[GameKind.Kind.BACCARAT] = 3.0
	_f.heat_rules.bet_change_bases[GameKind.Kind.HIGH_LOW] = 5.0


func _center(action: ActionKind.Kind, game: GameKind.Kind = GameKind.Kind.BLACKJACK) -> float:
	return _f.heat_rules.center(game, action)


## The game's bet-change base at the tier the hand started in (clean here).
func _base(game: GameKind.Kind = GameKind.Kind.BLACKJACK) -> float:
	return _f.heat_rules.bet_change_base(game)


func _amounts(heat: HandHeat) -> Array[float]:
	var amounts: Array[float] = []
	for line: HeatLine in heat.lines:
		amounts.append(line.amount)
	return amounts


## Reveals the hole card's colour in the hole-card window, then adjusts to
## first (and then second, if given) in the next adjusts.
func _blackjack_raise(first: int, second: int) -> HandActions:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.adjust(first)
	rnd.proceed()
	rnd.hit()
	rnd.proceed()
	if second > 0:
		rnd.adjust(second)
	actions.heat.resolve(rnd)
	return actions


## §1.1: doubles, splits and insurance add no base, so on their own they
## cost nothing.
func test_a_double_alone_costs_nothing() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.proceed()
	rnd.double()
	actions.heat.resolve(rnd)
	assert_float(actions.heat.total()).is_equal(0.0)


func test_insurance_alone_costs_nothing() -> void:
	var rnd: BlackjackRound = _f.blackjack(["9", "A", "7", "5", "4"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.insure(rnd.insurance_max())
	actions.heat.resolve(rnd)
	assert_float(actions.heat.total()).is_equal(0.0)


## §1.1: an adjust with no actions costs the bet-change base × m(r).
func test_an_adjust_costs_the_base_times_the_multiplier() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.adjust(3000)
	actions.heat.resolve(rnd)
	var expected: float = _base(GameKind.Kind.HIGH_LOW) * _f.heat_rules.multiplier(3.0)
	assert_float(actions.heat.total()).is_equal_approx(expected, 0.0001)


## The adjust's base is its own line, before the multiplier's.
func test_each_bet_change_is_its_own_line() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A", "A", "A"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.switch_side()
	rnd.adjust(500)
	actions.heat.resolve(rnd)
	var kinds: Array[HeatLine.Kind] = []
	for line: HeatLine in actions.heat.lines:
		kinds.append(line.kind)
	assert_array(kinds).contains_exactly(
		[HeatLine.Kind.BET_CHANGE, HeatLine.Kind.BET_CHANGE, HeatLine.Kind.MULTIPLIER]
	)
	assert_int(actions.heat.lines[0].bet_change).is_equal(BetChange.Kind.SIDE_SWITCH)
	var expected: float = 2 * _base(GameKind.Kind.BACCARAT) * _f.heat_rules.multiplier(3.0)
	assert_float(actions.heat.total()).is_equal_approx(expected, 0.0001)


## §7.1: the base is priced by the tier the hand started in.
func test_the_bet_change_base_follows_the_tier() -> void:
	_f.tier = HeatTier.Kind.WATCHED
	var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.adjust(2000)
	actions.heat.resolve(rnd)
	var watched: float = _f.heat_rules.cost_multiplier(HeatTier.Kind.WATCHED)
	assert_float(actions.heat.lines[0].amount).is_equal_approx(
		_base(GameKind.Kind.HIGH_LOW) * watched, 0.0001
	)


## §1.1: r compares the final bet with the opening bet only, but each adjust
## adds its own base, so stepping up costs one base more than one raise.
func test_a_stepped_raise_pays_a_base_per_step() -> void:
	var stepped: HandActions = _blackjack_raise(2000, 3000)
	before_test()
	var direct: HandActions = _blackjack_raise(3000, 0)
	var reveal: float = _center(ActionKind.Kind.PARTIAL_REVEAL)
	var m: float = _f.heat_rules.multiplier(3.0)
	assert_float(stepped.heat.total()).is_equal_approx((reveal + 2 * _base()) * m, 0.0001)
	assert_float(direct.heat.total()).is_equal_approx((reveal + _base()) * m, 0.0001)


## §1.1: halving the bet costs the same as doubling it.
func test_multiplier_is_symmetric() -> void:
	var totals: Array[float] = []
	for new_total: int in [2000, 500]:
		before_test()
		var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
		var actions: HandActions = _f.actions(rnd)
		actions.partial_reveal(1, [PartialQuestion.Kind.RED])
		rnd.proceed()
		rnd.adjust(new_total)
		actions.heat.resolve(rnd)
		totals.append(actions.heat.total())
	var reveal: float = _center(ActionKind.Kind.PARTIAL_REVEAL, GameKind.Kind.HIGH_LOW)
	var expected: float = (
		(reveal + _base(GameKind.Kind.HIGH_LOW)) * _f.heat_rules.multiplier(2.0)
	)
	assert_float(totals[0]).is_equal_approx(expected, 0.0001)
	assert_float(totals[1]).is_equal_approx(totals[0], 0.0001)


## §3.2: any side switch, even one switched back, is r = 3.
func test_side_switch_counts_as_the_largest_change() -> void:
	var rnd: BaccaratRound = _f.baccarat(["2", "A", "3", "A", "A", "A"])
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(2, [PartialQuestion.Kind.HIGH])
	rnd.proceed()
	rnd.switch_side()
	rnd.switch_side()
	actions.heat.resolve(rnd)
	var reveal: float = _center(ActionKind.Kind.PARTIAL_REVEAL, GameKind.Kind.BACCARAT)
	var expected: float = (
		(reveal + 2 * _base(GameKind.Kind.BACCARAT)) * _f.heat_rules.multiplier(3.0)
	)
	assert_float(actions.heat.total()).is_equal_approx(expected, 0.0001)


## §1.4: the multiplier's effect is its own line, added at resolution.
func test_resolve_adds_the_multiplier_line() -> void:
	var actions: HandActions = _blackjack_raise(2000, 0)
	var line: HeatLine = actions.heat.lines.back()
	var subtotal: float = _center(ActionKind.Kind.PARTIAL_REVEAL) + _base()
	var m: float = _f.heat_rules.multiplier(2.0)
	assert_int(line.kind).is_equal(HeatLine.Kind.MULTIPLIER)
	assert_float(line.ratio).is_equal_approx(2.0, 0.0001)
	assert_float(line.amount).is_equal_approx(subtotal * (m - 1.0), 0.0001)


## §1.4: each action's heat is its own line the moment it lands.
func test_each_action_is_charged_as_it_lands() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	assert_int(actions.heat.lines.size()).is_equal(1)
	var line: HeatLine = actions.heat.lines[0]
	assert_int(line.kind).is_equal(HeatLine.Kind.ACTION)
	assert_int(line.action).is_equal(ActionKind.Kind.PARTIAL_REVEAL)
	assert_float(line.amount).is_equal(_center(ActionKind.Kind.PARTIAL_REVEAL))
	actions.full_reveal(3)
	assert_array(_amounts(actions.heat)).contains_exactly(
		[_center(ActionKind.Kind.PARTIAL_REVEAL), _center(ActionKind.Kind.FULL_REVEAL)]
	)


func test_refused_action_costs_nothing() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.full_reveal(0)
	assert_array(actions.heat.lines).is_empty()


## §1.5: actions in the first window acted in cost base; every later window
## costs ×1.7, not compounded.
func test_later_windows_pay_the_surcharge() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.full_reveal(5)
	var surcharge: float = _f.heat_rules.second_window_surcharge
	assert_float(surcharge).is_equal_approx(1.7, 0.0001)
	assert_array(_amounts(actions.heat)).contains_exactly(
		[
			_center(ActionKind.Kind.PARTIAL_REVEAL),
			_center(ActionKind.Kind.PARTIAL_REVEAL) * surcharge,
			_center(ActionKind.Kind.FULL_REVEAL) * surcharge,
		]
	)
	assert_float(actions.heat.lines[1].surcharge).is_equal(surcharge)


func test_first_window_acted_in_costs_base_even_if_not_the_first_opened() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	assert_float(actions.heat.total()).is_equal(_center(ActionKind.Kind.PARTIAL_REVEAL))


## Hook for Deep Read (§9): no surcharge on a second window.
func test_deep_read_removes_the_surcharge() -> void:
	_f.kit.deep_read = true
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	assert_float(actions.heat.total()).is_equal(2.0 * _center(ActionKind.Kind.PARTIAL_REVEAL))


## §3.3: each call in a chain is its own window.
func test_high_low_later_calls_pay_the_surcharge() -> void:
	var rnd: HighLowRound = _f.high_low(["5", "9", "2", "8"])
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(1, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.call_next(HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	actions.partial_reveal(2, [PartialQuestion.Kind.RED])
	var reveal: float = _center(ActionKind.Kind.PARTIAL_REVEAL, GameKind.Kind.HIGH_LOW)
	assert_array(_amounts(actions.heat)).contains_exactly(
		[reveal, reveal * _f.heat_rules.second_window_surcharge]
	)


## §7.1: Watched ×1.5, Marked ×2, by the tier when the hand started.
func test_tier_multiplies_action_costs(
	tier: int,
	multiplier: float,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[HeatTier.Kind.CLEAN, 1.0],
		[HeatTier.Kind.WATCHED, 1.5],
		[HeatTier.Kind.MARKED, 2.0],
	]
) -> void:
	_f.tier = tier as HeatTier.Kind
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.nudge(3, 1)
	var line: HeatLine = actions.heat.lines[0]
	assert_float(line.tier_multiplier).is_equal_approx(multiplier, 0.0001)
	assert_float(line.amount).is_equal_approx(_center(ActionKind.Kind.NUDGE) * multiplier, 0.0001)


## §2.3: marks cost 3, +3 per mark already made this session.
func test_marks_escalate_across_the_session() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.mark(0, 0)
	actions.mark(1, 1)
	var next_rnd: BlackjackRound = _f.next_blackjack()
	var next_actions: HandActions = _f.actions(next_rnd)
	next_actions.mark(2, 0)
	var step: float = _f.heat_rules.mark_step
	var mark: float = _center(ActionKind.Kind.MARK)
	assert_array(_amounts(actions.heat)).contains_exactly([mark, mark + step])
	assert_array(_amounts(next_actions.heat)).contains_exactly([mark + 2.0 * step])


func test_cost_of_previews_the_next_action() -> void:
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	assert_float(actions.cost_of(ActionKind.Kind.FULL_REVEAL)).is_equal(
		_center(ActionKind.Kind.FULL_REVEAL)
	)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	assert_float(actions.cost_of(ActionKind.Kind.FULL_REVEAL)).is_equal_approx(
		_center(ActionKind.Kind.FULL_REVEAL) * _f.heat_rules.second_window_surcharge, 0.0001
	)
	assert_int(actions.heat.lines.size()).is_equal(1)
