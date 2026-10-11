extends GdUnitTestSuite
## Baccarat points (spec §3.2): ace 1, 2–9 face value, tens and faces 0, and
## the total is the last digit of the sum.


func _hand(codes: Array) -> BaccaratHand:
	var hand: BaccaratHand = BaccaratHand.new()
	for code: String in codes:
		hand.add(Card.parse(code))
	return hand


# gdlint: ignore=unused-argument
func test_card_value(code: String, expected: int, test_parameters: Array = [
	["A", 1],
	["2", 2],
	["5", 5],
	["9", 9],
	["10", 0],
	["J", 0],
	["Q", 0],
	["K", 0],
]) -> void:
	assert_int(BaccaratHand.value(Card.parse(code))).is_equal(expected)


# gdlint: ignore=unused-argument
func test_total(codes: Array, expected: int, test_parameters: Array = [
	[["K", "Q"], 0],
	[["A", "K"], 1],
	[["4", "5"], 9],
	[["7", "8"], 5],
	[["9", "9"], 8],
	[["5", "5", "K"], 0],
	[["6", "7", "9"], 2],
]) -> void:
	assert_int(_hand(codes).total()).is_equal(expected)


# gdlint: ignore=unused-argument
func test_natural(codes: Array, natural: bool, test_parameters: Array = [
	[["8", "K"], true],
	[["4", "5"], true],
	[["9", "9"], true],
	[["7", "K"], false],
	[["A", "2", "6"], false],
	[["3", "3", "3"], false],
]) -> void:
	# §3.2: a two-card 8 or 9.
	assert_bool(_hand(codes).is_natural(8)).is_equal(natural)


func test_third_value() -> void:
	assert_int(_hand(["A", "2"]).third_value()).is_equal(BaccaratRules.NO_THIRD)
	assert_int(_hand(["A", "2", "Q"]).third_value()).is_equal(0)
	assert_int(_hand(["A", "2", "7"]).third_value()).is_equal(7)
