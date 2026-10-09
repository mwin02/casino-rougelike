extends GdUnitTestSuite
## Floor signatures (spec §5.3). Watchful pit rolls every table's heat bases
## high, Stingy house pays main-game winnings short at every table, Short
## nights cuts the hand clock. Floor 1 is the baseline; floor 5's boss rule
## is [OPEN] and changes nothing yet. Default config: roll shift +0.2,
## winnings paid at 90%, 15 hands cut from 60.

## Player 20 against dealer 17: the player wins.
const WIN: Array[String] = ["10", "10", "10", "7", "2", "2"]
## Player 17 against dealer 20: the player loses.
const LOSE: Array[String] = ["10", "10", "7", "10", "2", "2"]
## Player 7H 7D loses to dealer 19; Perfect Pairs (coloured, 24:1) wins.
const PAIRS: Array[String] = ["7H", "10", "7D", "9", "K", "K"]

var _f: FloorFixture
var _s: TableSessionFixture


func before_test() -> void:
	_f = FloorFixture.new()
	_s = TableSessionFixture.new()


func _of(kind: FloorSignature.Kind) -> FloorSignature:
	return FloorSignature.of(_f.config, kind)


func _hand(codes: Array[String], bet: int, side_bets: Array[SideBet] = []) -> HandSummary:
	_s.signature = _of(FloorSignature.Kind.STINGY_HOUSE)
	var session: TableSession = _s.sit(GameKind.Kind.BLACKJACK, codes)
	session.start_hand(bet, BaccaratRound.BetSide.PLAYER, side_bets)
	TableSessionFixture.play_out(session)
	return session.finish_hand()


func test_the_baseline_and_the_boss_change_nothing(
	kind: FloorSignature.Kind,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [[FloorSignature.Kind.BASELINE], [FloorSignature.Kind.BOSS]]
) -> void:
	var signature: FloorSignature = _of(kind)
	assert_int(signature.clock_hands(60)).is_equal(60)
	assert_int(signature.house_cut(1005)).is_equal(0)
	var rules: HeatRules = HeatRules.from_config(_f.config)
	var plain: Vector2 = rules.roll_range(TableStakes.Kind.LOW, false)
	signature.apply_heat(rules)
	assert_vector(rules.roll_range(TableStakes.Kind.LOW, false)).is_equal(plain)


func test_a_floor_without_a_signature_is_the_baseline() -> void:
	assert_int(_f.three_rows().signature.kind).is_equal(FloorSignature.Kind.BASELINE)


# Watchful pit


func test_watchful_pit_shifts_every_roll_range_up() -> void:
	var rules: HeatRules = HeatRules.from_config(_f.config)
	var plain: HeatRules = HeatRules.from_config(_f.config)
	_of(FloorSignature.Kind.WATCHFUL_PIT).apply_heat(rules)
	for stakes: TableStakes.Kind in TableStakes.Kind.values():
		for manipulation: bool in [false, true]:
			var shifted: Vector2 = rules.roll_range(stakes, manipulation)
			var before: Vector2 = plain.roll_range(stakes, manipulation)
			assert_vector(shifted).is_equal_approx(before + Vector2(0.2, 0.2), Vector2(1e-6, 1e-6))


func test_watchful_pit_tables_roll_within_the_shifted_range() -> void:
	var floor: Floor = _f.floor_on([_f.tables(0, 1, [])], _of(FloorSignature.Kind.WATCHFUL_PIT))
	floor.enter(floor.map.node_at(0, 1))
	var costs: TableCosts = floor.sit(0).table_heat.costs
	var rules: HeatRules = HeatRules.from_config(_f.config)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		var bounds: Vector2 = rules.roll_range(TableStakes.Kind.LOW, action in ActionKind.MANIPULATION)
		var center: float = rules.center(GameKind.Kind.HIGH_LOW, action)
		assert_float(costs.base_cost(action, 0)).is_greater_equal(center * (1.0 + bounds.x + 0.2) - 1e-6)
		assert_float(costs.base_cost(action, 0)).is_less_equal(center * (1.0 + bounds.y + 0.2) + 1e-6)


func test_a_new_dealer_on_a_watchful_pit_rolls_high_too() -> void:
	_s.signature = _of(FloorSignature.Kind.WATCHFUL_PIT)
	var session: TableSession = _s.sit(GameKind.Kind.BLACKJACK, WIN)
	var first: TableCosts = session.table_heat.costs
	session.table_heat.consequence = MarkedConsequence.Kind.NEW_DEALER
	# Above 90 even after a straight hand's cooling.
	session.table_heat.heat = 100.0
	session.start_hand(1000)
	TableSessionFixture.play_out(session)
	session.finish_hand()
	var costs: TableCosts = session.table_heat.costs
	assert_object(costs).is_not_same(first)
	var rules: HeatRules = HeatRules.from_config(_f.config)
	for action: ActionKind.Kind in ActionKind.Kind.values():
		var bounds: Vector2 = rules.roll_range(TableStakes.Kind.LOW, action in ActionKind.MANIPULATION)
		var center: float = rules.center(GameKind.Kind.BLACKJACK, action)
		assert_float(costs.base_cost(action, 0)).is_greater_equal(center * (1.0 + bounds.x + 0.2) - 1e-6)


# Stingy house


func test_stingy_house_pays_winnings_short_rounding_down() -> void:
	assert_int(_of(FloorSignature.Kind.STINGY_HOUSE).house_cut(1000)).is_equal(100)
	# 90% of 1,005 is 904.5, paid as 904.
	assert_int(_of(FloorSignature.Kind.STINGY_HOUSE).house_cut(1005)).is_equal(101)


func test_stingy_house_cuts_a_winning_hand() -> void:
	var summary: HandSummary = _hand(WIN, 1000)
	assert_int(summary.house_cut).is_equal(100)
	assert_int(summary.net).is_equal(900)


func test_stingy_house_leaves_a_loss_alone() -> void:
	var summary: HandSummary = _hand(LOSE, 1000)
	assert_int(summary.house_cut).is_equal(0)
	assert_int(summary.net).is_equal(-1000)


func test_stingy_house_leaves_side_bets_alone() -> void:
	var bets: Array[SideBet] = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, 500)]
	var summary: HandSummary = _hand(PAIRS, 1000, bets)
	assert_int(summary.house_cut).is_equal(0)
	var coloured: int = TuneConfig.load_default().get_int_list("side_bets", "perfect_pairs")[1]
	assert_int(summary.net).is_equal(500 * coloured - 1000)


## Dealer A + K is a natural: the main bet loses, insurance pays 2:1 in full.
func test_stingy_house_leaves_insurance_alone() -> void:
	_s.signature = _of(FloorSignature.Kind.STINGY_HOUSE)
	var session: TableSession = _s.sit(GameKind.Kind.BLACKJACK, ["10", "A", "7", "K", "2", "2"])
	session.start_hand(1000)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.insure(rnd.insurance_max())
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_int(summary.house_cut).is_equal(0)
	assert_int(summary.net).is_equal(rnd.net())


func test_stingy_house_settles_into_the_bankroll() -> void:
	_s.signature = _of(FloorSignature.Kind.STINGY_HOUSE)
	var session: TableSession = _s.sit(GameKind.Kind.BLACKJACK, WIN)
	session.start_hand(1000)
	TableSessionFixture.play_out(session)
	session.finish_hand()
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL + 900)


# Short nights


func test_short_nights_cuts_the_clock_before_extra_hands() -> void:
	_f.run.extra_hands = 3
	var floor: Floor = _f.floor_on([_f.tables(0, 1, [])], _of(FloorSignature.Kind.SHORT_NIGHTS))
	var hands: int = _f.config.get_int("clock", "hands_per_floor")
	assert_int(floor.clock.hands_left).is_equal(hands - 15 + 3)
