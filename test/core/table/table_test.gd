extends GdUnitTestSuite
## A table's stakes come from its floor and type (spec §5.1, §6.3).

var _config: TuneConfig = TuneConfig.load_default()


func test_low_stakes_table_reads_its_floor_range() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.BACCARAT, TableStakes.Kind.LOW, 1)
	assert_int(table.table_min).is_equal(_config.get_int_list("floors", "low_stakes_min")[0])
	assert_int(table.table_max).is_equal(_config.get_int_list("floors", "low_stakes_max")[0])


func test_high_stakes_table_reads_its_floor_range() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.HIGH_LOW, TableStakes.Kind.HIGH, 3)
	assert_int(table.table_min).is_equal(_config.get_int_list("floors", "high_stakes_min")[2])
	assert_int(table.table_max).is_equal(_config.get_int_list("floors", "high_stakes_max")[2])


func test_table_keeps_its_game_stakes_and_floor() -> void:
	var table: Table = Table.from_config(_config, GameKind.Kind.HIGH_LOW, TableStakes.Kind.HIGH, 3)
	assert_int(table.game).is_equal(GameKind.Kind.HIGH_LOW)
	assert_int(table.stakes).is_equal(TableStakes.Kind.HIGH)
	assert_int(table.floor_number).is_equal(3)
