extends GdUnitTestSuite
## Hand totals under the house rules (spec §3.1): bust threshold 23, so an ace
## counts 11 whenever the total stays at 22 or under.


func _hand(codes: Array) -> BlackjackHand:
	var hand: BlackjackHand = BlackjackHand.new(BlackjackRules.from_config(TuneConfig.load_default()))
	for code: String in codes:
		hand.add(Card.parse(code))
	return hand


# gdlint: ignore=unused-argument
func test_total(codes: Array, expected: int, soft: bool, test_parameters: Array = [
	[["A", "K"], 21, true],
	[["A", "A"], 22, true],
	[["A", "A", "A"], 13, true],
	[["A", "A", "K"], 22, true],
	[["A", "A", "K", "9"], 21, false],
	[["A", "6"], 17, true],
	[["A", "6", "5"], 22, true],
	[["A", "6", "6"], 13, false],
	[["K", "Q"], 20, false],
	[["K", "Q", "2"], 22, false],
	[["K", "Q", "3"], 23, false],
	[["7", "8", "9"], 24, false],
]) -> void:
	var hand: BlackjackHand = _hand(codes)
	assert_int(hand.total()).is_equal(expected)
	assert_bool(hand.is_soft()).is_equal(soft)


# gdlint: ignore=unused-argument
func test_bust_at_23(codes: Array, bust: bool, test_parameters: Array = [
	[["K", "Q", "2"], false],
	[["A", "A", "K"], false],
	[["K", "Q", "3"], true],
	[["K", "6", "7"], true],
]) -> void:
	# Spec §3.1 pins the bust threshold at 23.
	assert_bool(_hand(codes).is_bust()).is_equal(bust)


# gdlint: ignore=unused-argument
func test_natural(codes: Array, natural: bool, test_parameters: Array = [
	[["A", "K"], true],
	[["10", "A"], true],
	[["A", "A"], false],
	[["A", "5", "5"], false],
	[["K", "Q", "A"], false],
	[["K", "Q"], false],
]) -> void:
	assert_bool(_hand(codes).is_natural()).is_equal(natural)
