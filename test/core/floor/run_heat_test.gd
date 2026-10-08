extends GdUnitTestSuite
## Run heat consequences (spec §7.4, §7.5). From run heat 40 the pit boss
## watches a table on the floor, and one more at each of more_tables_at; a
## watched table is Watched from watched_from table heat. New watched tables
## come from rows the player hasn't reached. Run heat 100 ejects the player.
## Default config: thresholds 40, 70, 100; more tables at 60 and 80.

var _f: FloorFixture


func before_test() -> void:
	_f = FloorFixture.new()


func _watched(floor: Floor) -> Array[Table]:
	var result: Array[Table] = []
	for node: MapNode in floor.map.nodes:
		for table: Table in node.tables:
			if table.watched:
				result.append(table)
	return result


## Five rows of one-table nodes, one per row.
func _five_rows() -> Floor:
	var nodes: Array[MapNode] = []
	for r: int in 5:
		var next: Array[int] = []
		if r < 4:
			next.append(1)
		nodes.append(_f.tables(r, 1, next))
	return _f.floor_on(nodes)


## Sits at the first row's table and leaves with heat above its floor that
## rolls over as rollover run heat (stand-up share 20%).
func _leave_first_table(floor: Floor, rollover: float) -> void:
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	session.table_heat.heat = session.table_heat.heat_floor + rollover / 0.2
	floor.leave()


func test_the_tables_watched_follow_the_thresholds(
	heat: float,
	expected: int,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [[0.0, 0], [39.9, 0], [40.0, 1], [59.9, 1], [60.0, 2], [80.0, 3]]
) -> void:
	assert_int(RunHeat.from_config(_f.config).watched_tables(heat)).is_equal(expected)


func test_no_table_is_watched_below_40() -> void:
	_f.run.run_heat = 39.9
	assert_array(_watched(_five_rows())).is_empty()


func test_a_floor_started_at_40_watches_one_table() -> void:
	_f.run.run_heat = 40.0
	assert_array(_watched(_five_rows())).has_size(1)


func test_more_tables_are_watched_as_run_heat_rises() -> void:
	_f.run.run_heat = 80.0
	assert_array(_watched(_five_rows())).has_size(3)


func test_crossing_40_mid_floor_watches_a_table_ahead() -> void:
	_f.run.run_heat = 39.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 2.0)
	var watched: Array[Table] = _watched(floor)
	assert_array(watched).has_size(1)
	assert_object(watched[0]).is_same(floor.map.node_at(2, 1).tables[0])


func test_no_table_is_watched_when_no_table_lies_ahead() -> void:
	_f.run.run_heat = 39.0
	var floor: Floor = _f.floor_on([_f.tables(0, 1, [1]), _f.tables(1, 1, [])])
	floor.enter(floor.map.node_at(0, 1))
	floor.leave()
	floor.enter(floor.map.node_at(1, 1))
	var session: TableSession = floor.sit(0)
	session.table_heat.heat = 10.0
	floor.leave()
	assert_float(_f.run.run_heat).is_greater_equal(40.0)
	assert_array(_watched(floor)).is_empty()


func test_a_watched_table_is_watched_from_zero() -> void:
	_f.run.run_heat = 40.0
	var floor: Floor = _f.floor_on([_f.tables(0, 1, [])])
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	assert_bool(session.table.watched).is_true()
	assert_float(session.table_heat.heat).is_equal(0.0)
	assert_int(session.table_heat.tier()).is_equal(HeatTier.Kind.WATCHED)


func test_an_unwatched_table_starts_clean() -> void:
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	assert_int(floor.sit(0).table_heat.tier()).is_equal(HeatTier.Kind.CLEAN)


func test_reaching_100_ejects_the_player() -> void:
	_f.run.run_heat = 99.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 2.0)
	assert_bool(_f.run.lost).is_true()
	assert_bool(_f.run.ejected).is_true()
	assert_int(floor.phase).is_equal(Floor.Phase.DONE)


func test_just_under_100_plays_on() -> void:
	_f.run.run_heat = 97.0
	var floor: Floor = _f.three_rows()
	_leave_first_table(floor, 2.0)
	assert_bool(_f.run.lost).is_false()
	assert_int(floor.phase).is_equal(Floor.Phase.MAP)


func test_ejection_wins_over_the_marker() -> void:
	_f.run.run_heat = 99.0
	var floor: Floor = _f.three_rows()
	floor.enter(floor.map.node_at(0, 1))
	var session: TableSession = floor.sit(0)
	session.bankroll = 500
	session.table_heat.heat = 10.0
	floor.leave()
	assert_bool(_f.run.ejected).is_true()
	assert_bool(_f.run.marker_used).is_false()
