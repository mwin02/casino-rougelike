extends GdUnitTestSuite
## The fixed third-card rules (spec §3.2): the player draws on 0–5; the
## banker's draw depends on its total and the player's third card.


# gdlint: ignore=unused-argument
func test_player_draws(total: int, draws: bool, test_parameters: Array = [
	[0, true],
	[1, true],
	[2, true],
	[3, true],
	[4, true],
	[5, true],
	[6, false],
	[7, false],
]) -> void:
	assert_bool(BaccaratRules.player_draws(total)).is_equal(draws)


## Each row is one banker total. The pattern reads D (draws) or S (stands)
## against: no player third card, then a player third card worth 0 to 9.
# gdlint: ignore=unused-argument
func test_banker_draws(banker_total: int, pattern: String, test_parameters: Array = [
	[0, "DDDDDDDDDDD"],
	[1, "DDDDDDDDDDD"],
	[2, "DDDDDDDDDDD"],
	[3, "DDDDDDDDDSD"],
	[4, "DSSDDDDDDSS"],
	[5, "DSSSSDDDDSS"],
	[6, "SSSSSSSDDSS"],
	[7, "SSSSSSSSSSS"],
]) -> void:
	var thirds: Array[int] = [BaccaratRules.NO_THIRD, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for i: int in thirds.size():
		var expected: bool = pattern[i] == "D"
		var draws: bool = BaccaratRules.banker_draws(banker_total, thirds[i])
		assert_bool(draws).override_failure_message(
			"banker %d vs player third %d: expected %s" % [banker_total, thirds[i], pattern[i]]
		).is_equal(expected)
