extends GdUnitTestSuite
## The floor clock (spec §6.1): a pool of hands per floor, plus any extra
## hands bought on the floor before. Only a hand played at a table spends
## one; a table refuses a hand once the clock is out.

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


func _hand(session: TableSession) -> void:
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	session.finish_hand()


func test_the_clock_starts_at_the_floor_pool_plus_extra_hands() -> void:
	var hands: int = _f.config.get_int("clock", "hands_per_floor")
	assert_int(FloorClock.from_config(_f.config).hands_left).is_equal(hands)
	assert_int(FloorClock.from_config(_f.config, 4).hands_left).is_equal(hands + 4)


func test_each_table_hand_spends_one_tick() -> void:
	_f.clock = FloorClock.new(5)
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	_hand(session)
	_hand(session)
	assert_int(_f.clock.hands_left).is_equal(3)


func test_a_hand_in_progress_has_not_spent_its_tick() -> void:
	_f.clock = FloorClock.new(5)
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	session.start_hand(TableSessionFixture.BET)
	assert_int(_f.clock.hands_left).is_equal(5)


func test_the_clock_carries_across_tables() -> void:
	_f.clock = FloorClock.new(5)
	var first: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	_hand(first)
	first.stand_up()
	_hand(_f.again(GameKind.Kind.HIGH_LOW))
	assert_int(_f.clock.hands_left).is_equal(3)


func test_a_table_refuses_a_hand_once_the_clock_is_out() -> void:
	_f.clock = FloorClock.new(1)
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	_hand(session)
	assert_bool(_f.clock.is_out()).is_true()
	assert_bool(session.can_start_hand(TableSessionFixture.BET)).is_false()
	assert_object(session.start_hand(TableSessionFixture.BET)).is_null()
	assert_int(_f.clock.hands_left).is_equal(0)


func test_standing_up_spends_no_hands() -> void:
	_f.clock = FloorClock.new(5)
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	session.stand_up()
	assert_int(_f.clock.hands_left).is_equal(5)
