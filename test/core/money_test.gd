extends GdUnitTestSuite
## Money is whole dollars; fractions round down (spec §6.2).


# gdlint: ignore=unused-argument
func test_apply_ratio(amount: int, num: int, den: int, expected: int, test_parameters: Array = [
	[1000, 3, 2, 1500],
	[1000, 6, 5, 1200],
	[1001, 3, 2, 1501],
	[1003, 6, 5, 1203],
	[7, 6, 5, 8],
	[-7, 6, 5, -9],
]) -> void:
	assert_int(Money.apply_ratio(amount, num, den)).is_equal(expected)
