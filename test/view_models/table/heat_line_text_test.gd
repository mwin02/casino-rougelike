extends GdUnitTestSuite
## Each itemized heat line as the debug table words it (spec §1.4): actions,
## the multiplier, cooling and what the table did. Rolled costs and the
## multiplier's workings show only with reveal_costs.


func test_action_line_shows_its_heat() -> void:
	var line: HeatLine = HeatLine.for_action(ActionKind.Kind.NUDGE, 12.0, 1.7, 1.0)
	assert_str(HeatText.line_text(line, false)).is_equal("Nudge +20.4")


func test_revealed_action_line_shows_base_and_what_multiplied_it() -> void:
	var line: HeatLine = HeatLine.for_action(ActionKind.Kind.NUDGE, 12.0, 1.7, 1.5)
	assert_str(HeatText.line_text(line, true)).is_equal(
		"Nudge +30.6 (12 × 1.7 later window × 1.5 tier)"
	)


func test_revealed_action_line_at_base_shows_no_breakdown() -> void:
	var line: HeatLine = HeatLine.for_action(ActionKind.Kind.PARTIAL_REVEAL, 2.0, 1.0, 1.0)
	assert_str(HeatText.line_text(line, true)).is_equal("Partial reveal +2")


func test_multiplier_line_hides_its_workings() -> void:
	var line: HeatLine = HeatLine.for_multiplier(2.0, 1.5, 12.0)
	assert_str(HeatText.line_text(line, false)).is_equal("Bet change +6")


func test_revealed_multiplier_line_shows_ratio_and_multiplier() -> void:
	var line: HeatLine = HeatLine.for_multiplier(2.0, 1.5, 12.0)
	assert_str(HeatText.line_text(line, true)).is_equal("Bet change +6 (r 2.0, ×1.5)")


func test_multiplier_line_that_adds_nothing_is_not_shown() -> void:
	var line: HeatLine = HeatLine.for_multiplier(1.0, 1.0, 12.0)
	assert_str(HeatText.line_text(line, true)).is_equal("")


func test_cooling_line() -> void:
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.COOLING, -6.0)
	assert_str(HeatText.line_text(line, false)).is_equal("Straight hand -6")


func test_cooling_line_that_sheds_nothing_is_not_shown() -> void:
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.COOLING, 0.0)
	assert_str(HeatText.line_text(line, false)).is_equal("")


func test_tier_line() -> void:
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.TIER)
	line.tier = HeatTier.Kind.WATCHED
	assert_str(HeatText.line_text(line, false)).is_equal("Table is now Watched")


# gdlint: ignore=unused-argument
func test_consequence_line(kind: int, expected: String, test_parameters: Array = [
	[MarkedConsequence.Kind.HOUSE_DECK_SWAP, "The pit swaps in a house deck."],
	[MarkedConsequence.Kind.NEW_DEALER, "A new dealer takes the table."],
]) -> void:
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.CONSEQUENCE)
	line.consequence = kind as MarkedConsequence.Kind
	assert_str(HeatText.line_text(line, false)).is_equal(expected)


func test_backed_off_line() -> void:
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.BACKED_OFF)
	assert_str(HeatText.line_text(line, false)).is_equal("You're backed off")


func test_lines_text_skips_lines_with_nothing_to_show() -> void:
	var lines: Array[HeatLine] = [
		HeatLine.for_multiplier(1.0, 1.0, 0.0),
		HeatLine.for_table(HeatLine.Kind.COOLING, -1.5),
	]
	assert_array(HeatText.lines_text(lines, false)).contains_exactly(["Straight hand -1.5"])
