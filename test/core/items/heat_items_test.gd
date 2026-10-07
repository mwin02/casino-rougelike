extends GdUnitTestSuite
## The heat and information items that change what actions, bet changes,
## cooling and rollover cost (spec §9): Poker Face, House Regular, Comped
## Suite, Quiet Hands, Sleight, Tell Reader, and the Pit Ledger. Hands are
## priced at the spec's center costs. Card i has id i.

## Player 2 and 3, dealer 9 up and 7 in the hole (id 3); hits deal 4, 5, 6.
const HITS: Array[String] = ["2", "9", "3", "7", "4", "5", "6"]
const STAKE: int = 1000

var _f: ActionsFixture
var _s: TableSessionFixture
var _rules: ItemRules


func before_test() -> void:
	_f = ActionsFixture.new()
	_s = TableSessionFixture.new()
	_rules = ItemRules.from_config(_f.config)


func _center(action: ActionKind.Kind, game: GameKind.Kind = GameKind.Kind.BLACKJACK) -> float:
	return _f.heat_rules.center(game, action)


func _lines_of(heat: HandHeat, kind: HeatLine.Kind) -> Array[HeatLine]:
	var result: Array[HeatLine] = []
	for line: HeatLine in heat.lines:
		if line.kind == kind:
			result.append(line)
	return result


## A straight High or Low hand at the table minimum: the first call ties.
func _tie_hand(session: TableSession) -> HandSummary:
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	return session.finish_hand()


func _sit_high_low(bankroll: int = TableSessionFixture.BANKROLL) -> TableSession:
	return _s.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4), bankroll)


# Poker Face


func test_poker_face_makes_the_first_window_acted_in_free() -> void:
	_f.kit.add_item(ItemKind.Kind.POKER_FACE, _rules)
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	actions.full_reveal(4)
	assert_float(actions.heat.total()).is_equal(0.0)


func test_poker_face_charges_later_windows() -> void:
	_f.kit.add_item(ItemKind.Kind.POKER_FACE, _rules)
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	var surcharge: float = _f.heat_rules.second_window_surcharge
	var expected: float = _center(ActionKind.Kind.PARTIAL_REVEAL) * surcharge
	assert_float(actions.heat.total()).is_equal_approx(expected, 0.0001)


func test_poker_face_keeps_side_bet_heat() -> void:
	_f.kit.add_item(ItemKind.Kind.POKER_FACE, _rules)
	_f.side_bets = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE)]
	var actions: HandActions = _f.actions(_f.blackjack(["7H", "5S", "8D", "9C", "K", "K"]))
	actions.palm(2, 7, Card.Suit.DIAMONDS)
	assert_float(_lines_of(actions.heat, HeatLine.Kind.ACTION)[0].amount).is_equal(0.0)
	assert_float(_lines_of(actions.heat, HeatLine.Kind.SIDE_BET)[0].amount).is_greater(0.0)


func test_a_free_action_still_breaks_a_straight_hand() -> void:
	_s.kit.add_item(ItemKind.Kind.POKER_FACE, _rules)
	var session: TableSession = _s.sit(
		GameKind.Kind.BLACKJACK, TableSessionFixture.repeat("10", 8)
	)
	session.start_hand(TableSessionFixture.BET)
	var hole: Card = session.current_round().window_subjects()[0]
	session.current_hand().full_reveal(hole.id)
	TableSessionFixture.play_out(session)
	assert_bool(session.finish_hand().straight).is_false()


# House Regular and Comped Suite


func test_house_regular_cools_at_its_own_rate() -> void:
	_s.kit.add_item(ItemKind.Kind.HOUSE_REGULAR, _rules)
	var session: TableSession = _sit_high_low()
	session.table_heat.heat = 50.0
	var summary: HandSummary = _tie_hand(session)
	var stake_factor: float = _f.heat_rules.stake_factor(0.0)
	var expected: float = -50.0 * _rules.house_regular_cool_rate * stake_factor
	assert_float(_rules.house_regular_cool_rate).is_equal(0.15)
	assert_float(summary.cooling).is_equal_approx(expected, 0.0001)


func test_comped_suite_rolls_over_less_on_standing_up() -> void:
	_s.kit.add_item(ItemKind.Kind.COMPED_SUITE, _rules)
	var session: TableSession = _sit_high_low()
	session.table_heat.heat = 50.0
	var end: SessionEnd = session.stand_up()
	assert_float(end.run_heat_added).is_equal_approx(50.0 * _rules.comped_suite_rollover, 0.0001)


func test_comped_suite_rolls_over_less_on_going_broke() -> void:
	_s.kit.add_item(ItemKind.Kind.COMPED_SUITE, _rules)
	var session: TableSession = _sit_high_low(1200)
	session.table_heat.heat = 50.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BROKE)
	var expected: float = session.table_heat.heat * _rules.comped_suite_rollover
	assert_float(end.run_heat_added).is_equal_approx(expected, 0.0001)


func test_comped_suite_leaves_the_back_off_share() -> void:
	_s.kit.add_item(ItemKind.Kind.COMPED_SUITE, _rules)
	var session: TableSession = _sit_high_low()
	session.table_heat.heat = 95.0
	_tie_hand(session)
	var end: SessionEnd = session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	var share: float = _f.config.get_float("run_heat", "backed_off_rollover")
	var cap: float = _f.config.get_float("run_heat", "max_rollover")
	var expected: float = minf(session.table_heat.heat * share, cap)
	assert_float(end.run_heat_added).is_equal_approx(expected, 0.0001)


# Quiet Hands


## A lowered bet: High or Low, 1,000 down to 500.
func _lowered(item: bool) -> HandActions:
	if item:
		_f.kit.add_item(ItemKind.Kind.QUIET_HANDS, _rules)
	var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.adjust(500)
	actions.heat.resolve(rnd)
	return actions


func test_quiet_hands_drops_decreases_from_the_multiplier() -> void:
	var base: float = _f.heat_rules.bet_change_base(GameKind.Kind.HIGH_LOW)
	var without: HandActions = _lowered(false)
	assert_float(without.heat.total()).is_equal_approx(base * _f.heat_rules.multiplier(2.0), 0.0001)
	var actions: HandActions = _lowered(true)
	assert_float(actions.heat.ratio(_f.last_round)).is_equal(1.0)
	assert_float(actions.heat.total()).is_equal_approx(base, 0.0001)


## Spec §1.1 [OPEN]: whether a decrease still pays the base is a hook.
func test_quiet_hands_hook_can_make_a_decrease_free() -> void:
	_rules.quiet_hands_decrease_pays_base = false
	assert_float(_lowered(true).heat.total()).is_equal(0.0)


func test_quiet_hands_leaves_raises_alone() -> void:
	_f.kit.add_item(ItemKind.Kind.QUIET_HANDS, _rules)
	var rnd: HighLowRound = _f.high_low(["5", "9", "2"])
	var actions: HandActions = _f.actions(rnd)
	rnd.proceed()
	rnd.adjust(2000)
	actions.heat.resolve(rnd)
	assert_float(actions.heat.ratio(rnd)).is_equal(2.0)


# Sleight and Tell Reader


func test_sleight_cuts_the_nudge_but_not_its_side_bet_heat() -> void:
	_f.side_bets = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, STAKE)]
	var plain: HandActions = _f.actions(_f.blackjack(["7H", "5S", "8D", "9C", "K", "K"]))
	plain.nudge(2, -1)
	plain.finish()
	_f.kit.add_item(ItemKind.Kind.SLEIGHT, _rules)
	var sleight: HandActions = _f.actions(_f.blackjack(["7H", "5S", "8D", "9C", "K", "K"]))
	sleight.nudge(2, -1)
	var expected: float = _center(ActionKind.Kind.NUDGE) * _rules.sleight_nudge_pct / 100.0
	assert_int(_rules.sleight_nudge_pct).is_equal(60)
	var action: HeatLine = _lines_of(sleight.heat, HeatLine.Kind.ACTION)[0]
	assert_float(action.amount).is_equal_approx(expected, 0.0001)
	var side: float = _lines_of(sleight.heat, HeatLine.Kind.SIDE_BET)[0].amount
	var plain_side: float = _lines_of(plain.heat, HeatLine.Kind.SIDE_BET)[0].amount
	assert_float(side).is_equal_approx(plain_side, 0.0001)


func test_tell_reader_cuts_marks_at_low_stakes() -> void:
	_f.kit.add_item(ItemKind.Kind.TELL_READER, _rules)
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	actions.mark(0, 0)
	actions.mark(1, 0)
	var first: float = _center(ActionKind.Kind.MARK) - _rules.tell_reader_mark_cut
	var second: float = first + _f.heat_rules.mark_step
	assert_float(actions.heat.total()).is_equal_approx(first + second, 0.0001)


func test_tell_reader_leaves_high_stakes_marks() -> void:
	_f.kit.add_item(ItemKind.Kind.TELL_READER, _rules)
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var costs: TableCosts = TableCosts.centered(_f.heat_rules, GameKind.Kind.BLACKJACK)
	costs.stakes = TableStakes.Kind.HIGH
	var heat: HandHeat = HandHeat.new(
		_f.heat_rules, costs, HeatTier.Kind.CLEAN, _f.session, _f.kit
	)
	_f.actions(rnd, heat).mark(0, 0)
	assert_float(heat.total()).is_equal_approx(_center(ActionKind.Kind.MARK), 0.0001)


# Pit Ledger


func test_without_the_pit_ledger_the_table_stays_hidden() -> void:
	assert_object(_sit_high_low().ledger()).is_null()


func test_the_pit_ledger_shows_the_cost_rolls_and_the_consequence() -> void:
	_s.kit.add_item(ItemKind.Kind.PIT_LEDGER, _rules)
	var session: TableSession = _sit_high_low()
	var ledger: PitLedger = session.ledger()
	assert_object(ledger.costs).is_same(session.table_heat.costs)
	assert_int(ledger.consequence).is_equal(session.table_heat.consequence)
