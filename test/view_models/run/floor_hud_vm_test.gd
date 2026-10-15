extends GdUnitTestSuite
## The floor screens' standing numbers (block U4): the floor and its
## signature, the hand clock, the bankroll against the quota, and run heat
## against its thresholds (spec §6.1, §6.2, §7.4).

var _config: TuneConfig = TuneConfig.load_default()
var _run: Run
var _hud: FloorHudVM


func before_test() -> void:
	_run = Run.start(_config, 11)
	_hud = FloorHudVM.new(_run)


func test_floor_1_is_the_baseline() -> void:
	assert_str(_hud.floor_title()).is_equal("FLOOR 1 · BASELINE")


func test_a_later_floor_shows_its_signature() -> void:
	_run.state.bankroll = _run.floor.quota
	_run.floor.cash_out()
	_run.floor.check_quota()
	_run.floor.finish()
	_run.end_floor()
	_run.ride(0)
	var kind: FloorSignature.Kind = _run.floor.signature.kind
	var expected: String = "FLOOR 2 · " + SignatureText.name_of(kind).to_upper()
	assert_str(FloorHudVM.new(_run).floor_title()).is_equal(expected)


func test_every_signature_has_a_name_and_a_plain_line() -> void:
	for kind: FloorSignature.Kind in FloorSignature.Kind.values():
		assert_str(SignatureText.name_of(kind)).is_not_empty()
		assert_str(SignatureText.plain(kind)).is_not_empty()


func test_the_clock_shows_hands_left_of_the_floors_pool() -> void:
	var pool: int = _config.get_int("clock", "hands_per_floor")
	_run.floor.clock.hands_left = 27
	assert_str(_hud.hands_left_text()).is_equal("27 hands left")
	assert_str(_hud.hands_total_text()).is_equal("of %d" % pool)
	assert_float(_hud.hands_share()).is_equal_approx(27.0 / pool, 0.0001)
	_run.floor.clock.hands_left = 1
	assert_str(_hud.hands_left_text()).is_equal("1 hand left")


func test_the_bankroll_shows_against_the_quota() -> void:
	_run.state.bankroll = 104_800
	assert_str(_hud.bankroll_text()).is_equal("$104,800")
	assert_str(_hud.quota_text()).is_equal("Quota $140,000")
	assert_str(_hud.gap_text()).is_equal("$35,200 to go")
	assert_bool(_hud.at_quota()).is_false()
	assert_float(_hud.quota_share()).is_equal_approx(104_800.0 / 140_000.0, 0.0001)


func test_a_bankroll_at_the_quota_has_reached_it() -> void:
	_run.state.bankroll = 151_200
	assert_str(_hud.gap_text()).is_equal("Quota reached")
	assert_bool(_hud.at_quota()).is_true()
	assert_float(_hud.quota_share()).is_equal(1.0)


func test_run_heat_shows_whole_against_its_thresholds() -> void:
	_run.state.run_heat = 45.6
	assert_str(_hud.run_heat_text()).is_equal("46")
	assert_float(_hud.run_heat_share()).is_equal_approx(0.456, 0.0001)
	# Spec §7.4: pit boss 40, sweep 70, ejected 100.
	assert_array(_hud.heat_marks()).contains_exactly([40, 70, 100])
	assert_array(_hud.heat_mark_shares()).contains_exactly([0.4, 0.7, 1.0])


func test_the_pit_boss_shows_from_his_threshold() -> void:
	_run.state.run_heat = 39.0
	assert_bool(_hud.pit_boss()).is_false()
	_run.state.run_heat = 40.0
	assert_bool(_hud.pit_boss()).is_true()
