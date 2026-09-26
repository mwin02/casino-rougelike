extends GdUnitTestSuite
## High or Low pricing (spec §3.3). A correct call multiplies the chain value
## by remaining × (100 − cut) / (winners × 100), held between the 1× floor and
## the 3× per-call cap, rounded down to whole dollars (§6.2). The chain value
## never passes 20× stake. These pin the spec numbers: cut 7%, caps 3× and 20×.

var _rules: HighLowRules


func before_test() -> void:
	_rules = HighLowRules.from_config(TuneConfig.load_default())


func test_call_value_matches_the_formula(
	# gdlint: ignore=unused-argument
	value: int, winners: int, remaining: int, expected: int, test_parameters: Array = [
		# 51 × 93 / 2400 = ×1.97625.
		[1000, 24, 51, 1976],
		# ×1.97625 on 1001 is 1978.2, rounded down.
		[1001, 24, 51, 1978],
		# 51 × 93 / 3600 = ×1.3175.
		[1000, 36, 51, 1317],
		# 20 × 93 / 1000 = ×1.86, later in a chain.
		[3000, 10, 20, 5580],
		# ×9.486 is held at the 3× per-call cap.
		[1000, 5, 51, 3000],
		# ×0.988 ("higher" on an ace) is held at the 1× floor.
		[1000, 48, 51, 1000],
		# Every remaining card wins: ×0.93, floored.
		[1000, 20, 20, 1000],
	]
) -> void:
	assert_int(_rules.call_value(value, winners, remaining)).is_equal(expected)


func test_a_call_with_no_winners_pays_the_per_call_cap() -> void:
	# Only a manipulated card can win it; the owned deck gives it no chance.
	assert_int(_rules.call_value(1000, 0, 51)).is_equal(3000)


func test_chain_cap_is_twenty_times_the_stake() -> void:
	assert_int(_rules.chain_cap(1000)).is_equal(20000)
	assert_int(_rules.chain_cap(2500)).is_equal(50000)


func test_a_tie_keeps_half_the_value_rounded_down() -> void:
	assert_int(HighLowRules.tie_value(1000)).is_equal(500)
	assert_int(HighLowRules.tie_value(1001)).is_equal(500)
