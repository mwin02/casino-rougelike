extends GdUnitTestSuite
## The real table's stake window: opening-bet chips, the side bet rows with
## their toggles and steppers (spec §8), and what the stake leaves of the
## bankroll. Floor 1 low stakes unless a test says otherwise.

var _vm: StackedTableScreenVM
var _cap: int


func _sit(game: GameKind.Kind, bankroll: int = -1) -> void:
	_vm = StackedTableScreenVM.on(["7H", "5S", "7D", "9C", "K"])
	if bankroll >= 0:
		_vm.bankroll = bankroll
	_vm.setup.choose_game(game)
	_vm.sit_down()
	_cap = _vm.session().side_bet_cap()


func _row(kind: SideBetKind.Kind) -> SideBetRow:
	for row: SideBetRow in _vm.stake().side_rows():
		if row.kind == kind:
			return row
	return null


func test_chips_run_from_the_table_minimum_to_its_maximum() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	var table: Table = _vm.session().table
	var chips: Array[Choice] = _vm.bets.chips()
	assert_int(chips.size()).is_equal(4)
	assert_int(chips[0].id).is_equal(table.table_min)
	assert_int(chips[3].id).is_equal(table.table_max)
	assert_bool(chips[0].selected).is_true()
	_vm.bets.press_chip(chips[3].id)
	assert_int(_vm.bets.opening_bet).is_equal(table.table_max)
	assert_float(_vm.bets.opening_fraction()).is_equal(1.0)
	assert_str(_vm.bets.chips()[3].label).is_equal("$%dK" % (table.table_max / 1000))


func test_a_chip_the_bankroll_cannot_cover_is_disabled() -> void:
	_sit(GameKind.Kind.BLACKJACK, 1500)
	var chips: Array[Choice] = _vm.bets.chips()
	assert_bool(chips[0].enabled).is_true()
	assert_bool(chips[3].enabled).is_false()
	_vm.bets.press_chip(chips[3].id)
	assert_int(_vm.bets.opening_bet).is_equal(chips[0].id)


func test_each_game_lists_its_side_bets_with_what_they_pay() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	var rules: SideBetRules = SideBetRules.from_config(_vm.session().rules_config())
	var pairs: SideBetRow = _row(SideBetKind.Kind.PERFECT_PAIRS)
	assert_str(pairs.name).is_equal("Perfect Pairs")
	assert_array(pairs.pays[1]).contains_exactly(["Coloured", "%d:1" % rules.perfect_pairs[1]])
	assert_int(_vm.stake().side_rows().size()).is_equal(3)
	_sit(GameKind.Kind.BACCARAT)
	var dragon: SideBetRow = _row(SideBetKind.Kind.DRAGON_BONUS)
	assert_bool(dragon.picks_side).is_true()
	assert_array(dragon.pays[0]).contains_exactly(["Natural", "%d:1" % rules.dragon_natural])
	assert_array(dragon.pays[1]).contains_exactly(["By 9", "%d:1" % rules.dragon_bonus[5]])
	assert_array(dragon.pays[6]).contains_exactly(["4", "%d:1" % rules.dragon_bonus[0]])
	_sit(GameKind.Kind.HIGH_LOW)
	assert_bool(_row(SideBetKind.Kind.EXACT_RANK).picks_rank).is_true()


func test_a_side_bet_toggles_on_at_one_step_and_steps_within_the_cap() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	var kind: SideBetKind.Kind = SideBetKind.Kind.BUST_IT
	var step: int = _cap / SideBetsVM.FINE_STEPS
	assert_bool(_row(kind).on).is_false()
	assert_str(_row(kind).off_text).is_equal("OFF")
	_vm.side_bets.toggle(kind)
	assert_bool(_row(kind).on).is_true()
	assert_str(_row(kind).stake_text).is_equal(MoneyFormat.format(step))
	assert_bool(_row(kind).can_lower).is_false()
	_vm.side_bets.step_stake(kind, 1)
	assert_int(_vm.side_bets.total()).is_equal(step * 2)
	for i: int in SideBetsVM.FINE_STEPS:
		_vm.side_bets.step_stake(kind, 1)
	assert_int(_vm.side_bets.total()).is_equal(_cap)
	assert_bool(_row(kind).can_raise).is_false()


func test_a_side_bet_comes_back_on_at_the_stake_it_had() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	var kind: SideBetKind.Kind = SideBetKind.Kind.BUST_IT
	_vm.side_bets.toggle(kind)
	_vm.side_bets.step_stake(kind, 1)
	var stake: int = _vm.side_bets.total()
	_vm.side_bets.toggle(kind)
	assert_int(_vm.side_bets.total()).is_equal(0)
	assert_array(_vm.side_bets.bets()).is_empty()
	_vm.side_bets.toggle(kind)
	assert_int(_vm.side_bets.total()).is_equal(stake)


func test_a_side_bet_the_bankroll_cannot_cover_says_so() -> void:
	_sit(GameKind.Kind.BLACKJACK, 1000)
	var row: SideBetRow = _row(SideBetKind.Kind.BUST_IT)
	assert_bool(row.can_toggle).is_false()
	assert_str(row.off_text).is_equal("NOT ENOUGH")


func test_side_bets_lock_once_the_hand_is_dealt() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	_vm.side_bets.toggle(SideBetKind.Kind.BUST_IT)
	_vm.deal()
	var row: SideBetRow = _row(SideBetKind.Kind.BUST_IT)
	assert_bool(row.can_toggle or row.can_lower or row.can_raise).is_false()
	_vm.side_bets.toggle(SideBetKind.Kind.BUST_IT)
	assert_bool(_row(SideBetKind.Kind.BUST_IT).on).is_true()


func test_a_table_with_no_side_bets_has_no_rows() -> void:
	_vm = StackedTableScreenVM.on(["7H", "5S", "7D", "9C", "K"])
	var rule: Choice = StackedTableDebugVM.find(_vm.setup.house_rule_choices(), "No side bets")
	_vm.setup.choose_house_rule(rule.id)
	_vm.sit_down()
	assert_array(_vm.stake().side_rows()).is_empty()


func test_the_stake_is_the_opening_bet_plus_the_side_bets() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	_vm.side_bets.toggle(SideBetKind.Kind.BUST_IT)
	var total: int = _vm.bets.opening_bet + _vm.side_bets.total()
	assert_int(_vm.stake().total()).is_equal(total)
	assert_int(_vm.stake().room()).is_equal(_vm.bankroll - total)
	var shares: Vector2 = _vm.stake().shares()
	assert_float(shares.x).is_equal_approx(float(_vm.bets.opening_bet) / _vm.bankroll, 0.0001)
	assert_float(shares.y).is_equal_approx(float(_vm.side_bets.total()) / _vm.bankroll, 0.0001)


func test_the_adjust_range_follows_the_opening_bet() -> void:
	_sit(GameKind.Kind.BLACKJACK)
	var table: Table = _vm.session().table
	var limits: BetLimits = BetLimits.from_config(
		_vm.session().rules_config(), table.table_min, table.table_min, table.table_max
	)
	assert_str(_vm.stake().adjust_range_text()).is_equal(
		"%s–%s" % [MoneyFormat.format(limits.min_total()), MoneyFormat.format(limits.max_total())]
	)
