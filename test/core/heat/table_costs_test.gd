extends GdUnitTestSuite
## Per-table base cost rolls (spec §1.2) and per-game centers (§2.3, §3.3).
## Each action rolls on its own, within its family's range for the table's
## stakes. Marks roll as information.

const SEEDS: int = 200

var _rules: HeatRules


func before_test() -> void:
	_rules = HeatRules.from_config(TuneConfig.load_default())


func _roll(game: GameKind.Kind, stakes: TableStakes.Kind, roll_seed: int) -> TableCosts:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = roll_seed
	return TableCosts.roll(_rules, game, stakes, rng)


func _range_of(stakes: TableStakes.Kind, action: ActionKind.Kind) -> Vector2:
	return _rules.roll_range(stakes, action in ActionKind.MANIPULATION)


func test_rolls_stay_within_their_family_range() -> void:
	for stakes: TableStakes.Kind in [TableStakes.Kind.LOW, TableStakes.Kind.HIGH]:
		for game: GameKind.Kind in [
			GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT, GameKind.Kind.HIGH_LOW
		]:
			for roll_seed: int in SEEDS:
				var costs: TableCosts = _roll(game, stakes, roll_seed)
				for action: ActionKind.Kind in ActionKind.Kind.values():
					var bounds: Vector2 = _range_of(stakes, action)
					var center: float = _rules.center(game, action)
					var cost: float = costs.base_cost(action, 0)
					assert_float(cost).is_between(
						center * (1.0 + bounds.x) - 0.0001, center * (1.0 + bounds.y) + 0.0001
					)


## The rolls cover the range rather than sitting at the center.
func test_rolls_reach_both_ends_of_the_range() -> void:
	var center: float = _rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.SWITCH)
	var bounds: Vector2 = _range_of(TableStakes.Kind.HIGH, ActionKind.Kind.SWITCH)
	var lowest: float = INF
	var highest: float = -INF
	for roll_seed: int in SEEDS:
		var cost: float = _roll(GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, roll_seed).base_cost(
			ActionKind.Kind.SWITCH, 0
		)
		lowest = minf(lowest, cost)
		highest = maxf(highest, cost)
	var width: float = center * (bounds.y - bounds.x)
	assert_float(lowest).is_less(center * (1.0 + bounds.x) + width * 0.05)
	assert_float(highest).is_greater(center * (1.0 + bounds.y) - width * 0.05)


## §1.2: high-stakes tables roll higher manipulation costs; §5.1: low-stakes
## tables roll lower manipulation and mark costs.
func test_stakes_bias_the_ranges() -> void:
	var low_manipulation: Vector2 = _rules.roll_range(TableStakes.Kind.LOW, true)
	var high_manipulation: Vector2 = _rules.roll_range(TableStakes.Kind.HIGH, true)
	var low_information: Vector2 = _rules.roll_range(TableStakes.Kind.LOW, false)
	var high_information: Vector2 = _rules.roll_range(TableStakes.Kind.HIGH, false)
	assert_float(high_manipulation.x).is_greater(low_manipulation.x)
	assert_float(high_manipulation.y).is_greater(low_manipulation.y)
	assert_float(low_information.y).is_less(high_information.y)


func test_same_seed_rolls_the_same_costs() -> void:
	var a: TableCosts = _roll(GameKind.Kind.BACCARAT, TableStakes.Kind.LOW, 77)
	var b: TableCosts = _roll(GameKind.Kind.BACCARAT, TableStakes.Kind.LOW, 77)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		assert_float(a.base_cost(action, 1)).is_equal(b.base_cost(action, 1))


func test_different_seeds_roll_different_costs() -> void:
	var a: TableCosts = _roll(GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, 1)
	var b: TableCosts = _roll(GameKind.Kind.BLACKJACK, TableStakes.Kind.HIGH, 2)
	assert_float(a.base_cost(ActionKind.Kind.NUDGE, 0)).is_not_equal(
		b.base_cost(ActionKind.Kind.NUDGE, 0)
	)


## §2.3: each mark this session adds the step; the step rolls with the base.
func test_mark_step_rolls_with_its_base() -> void:
	var costs: TableCosts = _roll(GameKind.Kind.BLACKJACK, TableStakes.Kind.LOW, 5)
	var first: float = costs.base_cost(ActionKind.Kind.MARK, 0)
	var third: float = costs.base_cost(ActionKind.Kind.MARK, 2)
	var center: float = _rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.MARK)
	var factor: float = first / center
	assert_float(third).is_equal_approx(first + 2.0 * _rules.mark_step * factor, 0.0001)


## §2.3 blackjack reference centers.
func test_centered_costs_are_the_spec_centers(
	action: int,
	cost: float,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[ActionKind.Kind.PARTIAL_REVEAL, 2.0],
		[ActionKind.Kind.MARK, 3.0],
		[ActionKind.Kind.FULL_REVEAL, 4.0],
		[ActionKind.Kind.LOOK_AHEAD, 7.0],
		[ActionKind.Kind.RECOLOUR, 10.0],
		[ActionKind.Kind.NUDGE, 12.0],
		[ActionKind.Kind.SWITCH, 20.0],
		[ActionKind.Kind.PALM, 28.0],
	]
) -> void:
	var costs: TableCosts = TableCosts.centered(_rules, GameKind.Kind.BLACKJACK)
	assert_float(costs.base_cost(action as ActionKind.Kind, 0)).is_equal_approx(cost, 0.0001)


## §1.2, §3.3: each game prices reveals (look ahead included) and
## manipulations at its own factor of the blackjack reference centers. Mark is
## never scaled.
func test_each_game_scales_every_action_but_mark_by_its_own_factors() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	for game: GameKind.Kind in GameKind.Kind.values():
		var section: String = GameKind.config_section(game as GameKind.Kind)
		var reveal: float = config.get_float(section, "reveal_cost_factor")
		var manipulation: float = config.get_float(section, "manipulation_cost_factor")
		for action: ActionKind.Kind in ActionKind.Kind.values():
			var factor: float = 1.0
			if action in ActionKind.MANIPULATION:
				factor = manipulation
			elif action != ActionKind.Kind.MARK:
				factor = reveal
			var name: String = ActionKind.Kind.keys()[action]
			var key: String = name.to_lower()
			assert_float(_rules.center(game, action)).is_equal_approx(
				config.get_float("actions", key) * factor, 0.0001
			)


func test_factors_apply_per_game() -> void:
	_rules.reveal_factors[GameKind.Kind.BACCARAT] = 2.0
	_rules.manipulation_factors[GameKind.Kind.BACCARAT] = 3.0
	var reveal: float = _rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.FULL_REVEAL)
	var nudge: float = _rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.NUDGE)
	assert_float(_rules.center(GameKind.Kind.BACCARAT, ActionKind.Kind.FULL_REVEAL)).is_equal_approx(
		2.0 * reveal, 0.0001
	)
	assert_float(_rules.center(GameKind.Kind.BACCARAT, ActionKind.Kind.NUDGE)).is_equal_approx(
		3.0 * nudge, 0.0001
	)
