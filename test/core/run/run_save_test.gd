extends GdUnitTestSuite
## Saving and resuming a run (block 14): a run saved off a table seat, and
## resumed from the file, plays on exactly like the run that never stopped:
## on the map, at the quota check, in the end shop, and at the elevator.
## Stops, Rummage and sweeps restore with the floor (floor_save_test).
## Mid-table saves are refused.

const PATH: String = "user://test_run_save.bin"
const SEED: int = 31337
const STEPS: int = 40

var _config: TuneConfig = TuneConfig.load_default()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _resumed(run: Run) -> Run:
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	return SaveStore.load_from(_config, PATH)


## One plain move: on the map, enter the first next node; at a table, sit,
## play up to three hands at the minimum, and leave; at a stop, buy what's
## cheap and leave; settle the rest.
func _step(run: Run) -> void:
	if run.phase == Run.Phase.ELEVATOR:
		run.ride(0)
		return
	if run.phase != Run.Phase.FLOOR:
		return
	var floor: Floor = run.floor
	match floor.phase:
		Floor.Phase.MAP:
			floor.enter(floor.choices()[0])
		Floor.Phase.AT_TABLE:
			var session: TableSession = floor.sit(0)
			for i: int in 3:
				if session == null or not session.can_start_hand(session.table.table_min):
					break
				session.start_hand(session.table.table_min)
				TableSessionFixture.play_out(session)
				session.finish_hand()
			floor.leave()
		Floor.Phase.AT_STOP:
			if floor.shop != null and floor.shop.can_buy_tape():
				floor.shop.buy_tape()
			if floor.services != null:
				floor.services.skip_rummage()
			floor.leave()
		Floor.Phase.SWEEP:
			floor.sweep(floor.sweep_choices()[0])
		Floor.Phase.QUOTA_CHECK:
			floor.check_quota()
		Floor.Phase.END_SHOP:
			if floor.shop.can_buy_extra_hand():
				floor.shop.buy_extra_hand()
			floor.finish()
		Floor.Phase.DONE:
			run.end_floor()


func _walk_until(run: Run, done: Callable) -> void:
	for i: int in 200:
		if done.call():
			return
		_step(run)
	fail("never reached the save point")


## Plays both runs on the same moves and checks they stay identical.
func _assert_plays_on_alike(a: Run, b: Run) -> void:
	assert_dict(b.to_dict()).is_equal(a.to_dict())
	for i: int in STEPS:
		_step(a)
		_step(b)
	assert_dict(b.to_dict()).is_equal(a.to_dict())


## A run at its first quota check with the quota reached.
func _at_passing_check() -> Run:
	var run: Run = Run.start(_config, SEED)
	_walk_until(run, func() -> bool: return run.floor.phase == Floor.Phase.QUOTA_CHECK)
	run.state.bankroll = run.floor.quota
	return run


func test_a_run_resumed_on_the_map_plays_on_alike() -> void:
	var run: Run = Run.start(_config, SEED)
	_step(run)
	_step(run)
	_walk_until(run, func() -> bool: return run.floor.phase == Floor.Phase.MAP)
	_assert_plays_on_alike(run, _resumed(run))


func test_a_run_resumed_at_the_quota_check_plays_on_alike() -> void:
	var run: Run = _at_passing_check()
	_assert_plays_on_alike(run, _resumed(run))


func test_a_run_resumed_in_the_end_shop_plays_on_alike() -> void:
	var run: Run = _at_passing_check()
	run.floor.check_quota()
	assert_int(run.floor.phase).is_equal(Floor.Phase.END_SHOP)
	_assert_plays_on_alike(run, _resumed(run))


func test_a_run_resumed_at_the_elevator_plays_on_alike() -> void:
	var run: Run = _at_passing_check()
	run.state.run_heat = 30.0
	run.floor.check_quota()
	run.floor.finish()
	run.end_floor()
	assert_int(run.phase).is_equal(Run.Phase.ELEVATOR)
	var resumed: Run = _resumed(run)
	assert_int(resumed.options.size()).is_equal(2)
	for i: int in 2:
		assert_int(resumed.options[i].kind).is_equal(run.options[i].kind)
	_assert_plays_on_alike(run, resumed)


func test_watched_tables_survive_a_resume() -> void:
	var run: Run = Run.start(_config, SEED)
	run.state.run_heat = 80.0
	run.floor = Floor.new(
		_config, run.state, run.game.deck, run.game.layer, run.kit, run.game.rng
	)
	var resumed: Run = _resumed(run)
	var watched: int = 0
	for node: MapNode in resumed.floor.map.nodes:
		for table: Table in node.tables:
			if table.watched:
				watched += 1
	assert_int(watched).is_equal(3)


func test_a_seated_run_cant_save_yet() -> void:
	var run: Run = Run.start(_config, SEED)
	_walk_until(run, func() -> bool: return run.floor.phase == Floor.Phase.AT_TABLE)
	run.floor.sit(0)
	assert_bool(run.can_save()).is_false()
	assert_int(SaveStore.save(run, PATH)).is_equal(ERR_BUSY)
