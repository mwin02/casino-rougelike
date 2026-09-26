extends GdUnitTestSuite
## Dollar display: commas up to $999,999, short form above (one decimal, cut
## not rounded, so the screen never shows more than the player has).


# gdlint: ignore=unused-argument
func test_format(amount: int, expected: String, test_parameters: Array = [
	[0, "$0"],
	[25, "$25"],
	[1000, "$1,000"],
	[140000, "$140,000"],
	[999999, "$999,999"],
	[1000000, "$1M"],
	[3125000, "$3.1M"],
	[3500000, "$3.5M"],
	[12500000, "$12.5M"],
	[87500000, "$87.5M"],
	[1999999, "$1.9M"],
	[1250000000, "$1.2B"],
	[-1000, "-$1,000"],
	[-3500000, "-$3.5M"],
]) -> void:
	assert_str(MoneyFormat.format(amount)).is_equal(expected)


# gdlint: ignore=unused-argument
func test_format_signed(amount: int, expected: String, test_parameters: Array = [
	[1500, "+$1,500"],
	[-1000, "-$1,000"],
	[0, "$0"],
]) -> void:
	assert_str(MoneyFormat.format_signed(amount)).is_equal(expected)
