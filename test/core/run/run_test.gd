extends GdUnitTestSuite
## The tower (spec §5.3, §6.3, §7.4, §11): five floors, floor 1 at the
## baseline. After each passed floor the elevator offers two signatures for
## floors 2–4 and only the boss floor for floor 5; the ride sheds run heat
## (15–20). Quotas and stakes follow each floor's config. Floor 5's quota
## wins; a lost floor loses the run. Score: final bankroll and dollars per
## heat.

const SEED: int = 4242

var _config: TuneConfig = TuneConfig.load_default()


func _run() -> Run:
	return Run.start(_config, SEED)


## Passes the current floor by cashing out with enough money, and leaves it.
func _pass_floor(run: Run) -> void:
	run.state.bankroll = maxi(run.state.bankroll, run.floor.quota)
	run.floor.cash_out()
	run.floor.check_quota()
	run.floor.finish()
	run.end_floor()


## Climbs to floor_number, taking the first option at each elevator.
func _climb(run: Run, floor_number: int) -> void:
	while run.state.floor_number < floor_number:
		_pass_floor(run)
		run.ride(0)


func test_a_run_starts_on_floor_1_at_the_baseline() -> void:
	var run: Run = _run()
	assert_int(run.phase).is_equal(Run.Phase.FLOOR)
	assert_int(run.state.floor_number).is_equal(1)
	assert_int(run.state.bankroll).is_equal(_config.get_int("floors", "start_bankroll"))
	assert_int(run.floor.signature.kind).is_equal(FloorSignature.Kind.BASELINE)


func test_a_passed_floor_opens_the_elevator() -> void:
	var run: Run = _run()
	_pass_floor(run)
	assert_int(run.phase).is_equal(Run.Phase.ELEVATOR)
	assert_int(run.state.floor_number).is_equal(2)


func test_a_floor_still_in_play_doesnt_end() -> void:
	var run: Run = _run()
	assert_bool(run.end_floor()).is_false()
	assert_int(run.phase).is_equal(Run.Phase.FLOOR)


func test_the_elevator_offers_two_signatures_for_floors_2_to_4() -> void:
	var run: Run = _run()
	for floor_number: int in [2, 3, 4]:
		_climb(run, floor_number - 1)
		_pass_floor(run)
		var options: Array[FloorSignature] = run.options
		assert_array(options).has_size(2)
		assert_int(options[0].kind).is_not_equal(options[1].kind)
		for option: FloorSignature in options:
			assert_bool(option.kind in FloorSignature.POOL).is_true()
		run.ride(0)


func test_the_elevator_to_floor_5_offers_only_the_boss() -> void:
	var run: Run = _run()
	_climb(run, 4)
	_pass_floor(run)
	assert_array(run.options).has_size(1)
	assert_int(run.options[0].kind).is_equal(FloorSignature.Kind.BOSS)


func test_the_ride_starts_the_next_floor_with_the_chosen_signature() -> void:
	var run: Run = _run()
	_pass_floor(run)
	var chosen: FloorSignature.Kind = run.options[1].kind
	assert_bool(run.ride(1)).is_true()
	assert_int(run.phase).is_equal(Run.Phase.FLOOR)
	assert_int(run.floor.signature.kind).is_equal(chosen)
	assert_array(run.options).is_empty()


func test_the_ride_is_refused_away_from_the_elevator_or_off_its_options() -> void:
	var run: Run = _run()
	assert_bool(run.ride(0)).is_false()
	_pass_floor(run)
	assert_bool(run.ride(2)).is_false()
	assert_bool(run.ride(-1)).is_false()
	assert_int(run.phase).is_equal(Run.Phase.ELEVATOR)


func test_the_elevator_sheds_run_heat() -> void:
	var run: Run = _run()
	_pass_floor(run)
	run.state.run_heat = 50.0
	run.ride(0)
	var low: float = _config.get_float("run_heat", "elevator_shed_min")
	var high: float = _config.get_float("run_heat", "elevator_shed_max")
	assert_float(run.last_shed).is_between(low, high)
	assert_float(run.state.run_heat).is_equal_approx(50.0 - run.last_shed, 1e-6)


func test_the_elevator_never_sheds_below_zero() -> void:
	var run: Run = _run()
	_pass_floor(run)
	run.state.run_heat = 5.0
	run.ride(0)
	assert_float(run.state.run_heat).is_equal(0.0)
	assert_float(run.last_shed).is_equal(5.0)


func test_quotas_and_stakes_scale_per_floor() -> void:
	var run: Run = _run()
	for floor_number: int in range(1, TuneSchema.FLOORS + 1):
		_climb(run, floor_number)
		var i: int = floor_number - 1
		assert_int(run.floor.quota).is_equal(_config.get_int_list("floors", "quotas")[i])
		for node: MapNode in run.floor.map.nodes:
			for table: Table in node.tables:
				var prefix: String = "high_stakes" if node.is_high_stakes() else "low_stakes"
				assert_int(table.floor_number).is_equal(floor_number)
				assert_int(table.table_min).is_equal(_config.get_int_list("floors", prefix + "_min")[i])
				assert_int(table.table_max).is_equal(_config.get_int_list("floors", prefix + "_max")[i])


func test_reaching_floor_5s_quota_wins_the_run() -> void:
	var run: Run = _run()
	_climb(run, 5)
	run.state.bankroll = run.floor.quota
	run.floor.cash_out()
	assert_int(run.floor.check_quota().result).is_equal(QuotaCheck.Result.WON)
	assert_bool(run.end_floor()).is_true()
	assert_int(run.phase).is_equal(Run.Phase.WON)


func test_a_lost_floor_loses_the_run() -> void:
	var run: Run = _run()
	run.state.marker_used = true
	run.floor.clock.hands_left = 0
	run.floor.enter(run.floor.map.row(0)[0])
	run.floor.leave()
	assert_int(run.floor.check_quota().result).is_equal(QuotaCheck.Result.LOST)
	assert_bool(run.end_floor()).is_true()
	assert_int(run.phase).is_equal(Run.Phase.LOST)


func test_the_floors_heat_spent_counts_toward_the_score() -> void:
	var run: Run = _run()
	run.floor.enter(run.floor.map.row(0)[0])
	var session: TableSession = run.floor.sit(0)
	session.session_heat = 12.5
	run.floor.leave()
	assert_float(run.state.heat_spent).is_equal(12.5)


func test_the_score_is_the_bankroll_and_dollars_per_heat() -> void:
	var state: RunState = RunState.new_run(_config)
	state.bankroll = state.start_bankroll + 90_000
	state.heat_spent = 30.0
	var score: RunScore = RunScore.of(state)
	assert_int(score.bankroll).is_equal(state.bankroll)
	assert_int(score.profit).is_equal(90_000)
	assert_float(score.dollars_per_heat).is_equal_approx(3000.0, 1e-6)


func test_a_run_without_heat_has_no_rate() -> void:
	var state: RunState = RunState.new_run(_config)
	assert_float(RunScore.of(state).dollars_per_heat).is_equal(0.0)


func test_the_same_seed_offers_the_same_elevator() -> void:
	var a: Run = _run()
	var b: Run = _run()
	_pass_floor(a)
	_pass_floor(b)
	for i: int in 2:
		assert_int(a.options[i].kind).is_equal(b.options[i].kind)
