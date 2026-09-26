extends GdUnitTestSuite
## One run seed, independent named streams (block 1).


func _draws(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.randi())
	return values


func test_same_seed_gives_same_streams() -> void:
	var a: GameRng = GameRng.new(99)
	var b: GameRng = GameRng.new(99)
	for s: int in GameRng.Stream.values():
		var stream: GameRng.Stream = s as GameRng.Stream
		assert_array(_draws(a.stream(stream), 5)).is_equal(_draws(b.stream(stream), 5))


func test_streams_differ_from_each_other() -> void:
	var rng: GameRng = GameRng.new(99)
	var shuffle: Array[int] = _draws(rng.stream(GameRng.Stream.SHUFFLE), 5)
	var rolls: Array[int] = _draws(rng.stream(GameRng.Stream.TABLE_ROLLS), 5)
	assert_array(shuffle).is_not_equal(rolls)


func test_drawing_one_stream_leaves_others_alone() -> void:
	var busy: GameRng = GameRng.new(99)
	var quiet: GameRng = GameRng.new(99)
	_draws(busy.stream(GameRng.Stream.TABLE_ROLLS), 10)
	var busy_shuffle: Array[int] = _draws(busy.stream(GameRng.Stream.SHUFFLE), 5)
	var quiet_shuffle: Array[int] = _draws(quiet.stream(GameRng.Stream.SHUFFLE), 5)
	assert_array(busy_shuffle).is_equal(quiet_shuffle)


func test_different_seeds_give_different_shuffles() -> void:
	var a: Array[int] = _draws(GameRng.new(1).stream(GameRng.Stream.SHUFFLE), 5)
	var b: Array[int] = _draws(GameRng.new(2).stream(GameRng.Stream.SHUFFLE), 5)
	assert_array(a).is_not_equal(b)
