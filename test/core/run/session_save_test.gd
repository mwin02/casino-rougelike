extends GdUnitTestSuite
## A run saved while seated, between hands (block 14), resumes at the same
## table: its money, heat, costs, Marked consequence, house deck, Palm and
## marks this session, and an ending not yet walked away from. Played on, it
## matches the run that never stopped.

const PATH: String = "user://test_session_save.bin"

var _config: TuneConfig = TuneConfig.load_default()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## A run seated at the first table of a hand-made floor: a High or Low table
## node, a shop, then a high-stakes node.
func _seated(signature: FloorSignature = null) -> Run:
	var run: Run = Run.start(_config, 11)
	var f: FloorFixture = FloorFixture.new()
	var nodes: Array[MapNode] = [
		f.tables(0, 1, [1]),
		f.back_room(1, 1, MapNode.Kind.SHOP, [1]),
		f.tables(2, 1, [], TableStakes.Kind.HIGH),
	]
	run.floor = Floor.new(
		_config, run.state, run.game.deck, run.game.layer, run.kit, run.game.rng,
		FloorMap.from_nodes(3, nodes), signature
	)
	run.floor.enter(run.floor.map.node_at(0, 1))
	run.floor.sit(0)
	return run


func _resumed(run: Run) -> Run:
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	var resumed: Run = SaveStore.load_from(_config, PATH)
	assert_object(resumed).is_not_null()
	return resumed


func _play(run: Run, hands: int) -> void:
	var session: TableSession = run.floor.session
	for i: int in hands:
		if not session.can_start_hand(session.table.table_min):
			return
		session.start_hand(session.table.table_min)
		TableSessionFixture.play_out(session)
		session.finish_hand()


## Six more hands, leave, and the rest of the floor, the same on both.
func _assert_plays_on_alike(a: Run, b: Run) -> void:
	assert_dict(b.to_dict()).is_equal(a.to_dict())
	for run: Run in [a, b]:
		_play(run, 6)
		run.floor.leave()
		run.floor.enter(run.floor.map.node_at(1, 1))
		run.floor.leave()
		run.floor.enter(run.floor.map.node_at(2, 1))
		run.floor.sit(0)
		_play(run, 3)
		run.floor.leave()
	assert_dict(b.to_dict()).is_equal(a.to_dict())


## Plays one hand starting at table heat 70, so it reaches Marked and the
## consequence fires, after setting which one.
func _fire(run: Run, consequence: MarkedConsequence.Kind) -> void:
	var heat: TableHeat = run.floor.session.table_heat
	heat.consequence = consequence
	heat.heat = 100.0
	_play(run, 1)
	assert_bool(heat.consequence_fired).is_true()


func test_a_seated_run_resumes_between_hands_and_plays_on_alike() -> void:
	var run: Run = _seated()
	_play(run, 2)
	var resumed: Run = _resumed(run)
	assert_int(resumed.floor.session.hands_played).is_equal(2)
	assert_int(resumed.floor.session.bankroll).is_equal(run.floor.session.bankroll)
	assert_object(resumed.floor.session.table).is_same(resumed.floor.current.tables[0])
	_assert_plays_on_alike(run, resumed)


func test_resuming_draws_no_new_rolls() -> void:
	var run: Run = _seated()
	var before: Dictionary = run.game.rng.to_dict()
	var resumed: Run = _resumed(run)
	assert_dict(resumed.game.rng.to_dict()).is_equal(before)


func test_a_house_deck_swap_survives_a_resume() -> void:
	var run: Run = _seated()
	_fire(run, MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	var resumed: Run = _resumed(run)
	assert_bool(resumed.floor.session.house_deck_swapped()).is_true()
	_assert_plays_on_alike(run, resumed)


func test_a_new_dealers_costs_survive_a_resume() -> void:
	var run: Run = _seated()
	_fire(run, MarkedConsequence.Kind.NEW_DEALER)
	var resumed: Run = _resumed(run)
	var costs: Dictionary = resumed.floor.session.table_heat.costs.to_dict()
	assert_dict(costs).is_equal(run.floor.session.table_heat.costs.to_dict())
	_assert_plays_on_alike(run, resumed)


func test_a_used_palm_and_marks_made_survive_a_resume() -> void:
	var run: Run = _seated()
	# Set directly: the session's action state has no public setter.
	run.floor.session._action_session.palm_used = true
	run.floor.session._action_session.marks_made = 2
	var resumed: Run = _resumed(run)
	assert_bool(resumed.floor.session._action_session.palm_used).is_true()
	assert_int(resumed.floor.session._action_session.marks_made).is_equal(2)
	_assert_plays_on_alike(run, resumed)


## High or Low prices against the deck as it stood at sit-down (§3.3), so a
## deck changed since then (a Cold Seal, say) must not reach the prices.
func test_the_sit_down_deck_keeps_pricing_after_a_resume() -> void:
	var run: Run = _seated()
	var card: Card = run.game.deck.cards()[0]
	run.game.deck.make_permanent(card.id, 13, card.suit, DeckEdit.Kind.COLD_SEAL)
	var resumed: Run = _resumed(run)
	var priced: Array = resumed.to_dict()["floor"]["session"][0]["priced_deck"]
	assert_int(priced[0]["rank"]).is_equal(card.rank)
	_assert_plays_on_alike(run, resumed)


func test_a_backed_off_session_resumes_ended() -> void:
	var run: Run = _seated()
	run.floor.session.table_heat.heat = 140.0
	_play(run, 1)
	assert_object(run.floor.session.ended()).is_not_null()
	var resumed: Run = _resumed(run)
	var end: SessionEnd = resumed.floor.session.ended()
	assert_int(end.reason).is_equal(SessionEnd.Reason.BACKED_OFF)
	assert_float(end.run_heat_added).is_equal(run.floor.session.ended().run_heat_added)
	run.floor.leave()
	resumed.floor.leave()
	assert_dict(resumed.to_dict()).is_equal(run.to_dict())


func test_a_resumed_watched_table_on_a_watchful_floor_keeps_its_rules() -> void:
	var run: Run = _seated(FloorSignature.of(_config, FloorSignature.Kind.WATCHFUL_PIT))
	run.floor.leave()
	run.floor.current.tables[0].watched = true
	var floor: Floor = run.floor
	floor.phase = Floor.Phase.AT_TABLE
	floor.sit(0)
	var resumed: Run = _resumed(run)
	assert_int(resumed.floor.session.table_heat.tier()).is_equal(HeatTier.Kind.WATCHED)
	assert_int(resumed.floor.signature.kind).is_equal(FloorSignature.Kind.WATCHFUL_PIT)


func test_bad_session_values_are_refused(
	field: String,
	value: Variant,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["reason", 9], ["rank", 14], ["suit", 9]]
) -> void:
	var run: Run = _seated()
	run.floor.session.table_heat.heat = 140.0
	_play(run, 1)
	var saved: Dictionary = run.to_dict()
	var session: Dictionary = saved["floor"]["session"][0]
	if field == "reason":
		session["ended"][0]["reason"] = value
	else:
		session["priced_deck"][0][field] = value
	assert_object(SaveStore.from_saved(saved, _config)).is_null()


func test_a_seated_table_off_the_node_is_refused() -> void:
	var saved: Dictionary = _seated().to_dict()
	var session: Dictionary = saved["floor"]["session"][0]
	session["table_index"] = 5
	assert_object(SaveStore.from_saved(saved, _config)).is_null()
