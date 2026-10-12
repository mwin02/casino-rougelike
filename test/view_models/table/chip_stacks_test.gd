extends GdUnitTestSuite
## Money as chips: denominations ten times apart from $100, a sum's two
## largest shown, the rest rounded to the nearest chip of the second.


func _text(amount: int) -> String:
	var parts: PackedStringArray = []
	for stack: ChipStacks.Stack in ChipStacks.of(amount):
		parts.append("%d×%d" % [stack.count, ChipStacks.value(stack.denomination)])
	return " ".join(parts)


func test_a_sum_shows_as_its_two_largest_denominations(
	# gdlint: ignore=unused-argument
	amount: int, expected: String, test_parameters: Array = [
		[0, ""],
		[40, ""],
		[60, "1×100"],
		[100, "1×100"],
		[900, "9×100"],
		[1000, "1×1000"],
		[4000, "4×1000"],
		[4300, "4×1000 3×100"],
		[4340, "4×1000 3×100"],
		[4360, "4×1000 4×100"],
		[12000, "1×10000 2×1000"],
		[12400, "1×10000 2×1000"],
		[1260000, "1×1000000 3×100000"],
		[87500000, "8×10000000 8×1000000"],
	]
) -> void:
	assert_str(_text(amount)).is_equal(expected)


func test_rounding_up_carries_into_the_next_denomination() -> void:
	assert_str(_text(9960)).is_equal("1×10000")
	assert_str(_text(99960)).is_equal("1×100000")


func test_more_money_never_shows_as_less() -> void:
	var before: int = 0
	for amount: int in range(0, 60000, 37):
		var now: int = ChipStacks.shown(amount)
		assert_bool(now >= before).is_true()
		before = now


func test_a_sum_is_never_more_than_two_stacks_of_nine() -> void:
	for amount: int in [999, 9999, 99999, 9999999, 99999999]:
		var stacks: Array[ChipStacks.Stack] = ChipStacks.of(amount)
		assert_bool(stacks.size() <= 2).is_true()
		for stack: ChipStacks.Stack in stacks:
			assert_bool(stack.count <= 9).is_true()


func test_past_the_largest_chip_the_stack_just_grows() -> void:
	var top: int = ChipStacks.value(ChipStacks.DENOMINATIONS - 1)
	assert_int(ChipStacks.of(top * 12)[0].count).is_equal(12)
