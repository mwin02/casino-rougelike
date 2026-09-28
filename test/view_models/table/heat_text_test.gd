extends GdUnitTestSuite
## Heat numbers, the hand's summary line, tier names and cost previews
## (spec §1.4). Each heat line's text is in heat_line_text_test.


# gdlint: ignore=unused-argument
func test_amount(heat: float, expected: String, test_parameters: Array = [
	[12.0, "+12"],
	[20.4, "+20.4"],
	[20.46, "+20.5"],
	[-6.0, "-6"],
	[-0.04, "0"],
	[0.0, "0"],
]) -> void:
	assert_str(HeatText.amount(heat)).is_equal(expected)


# gdlint: ignore=unused-argument
func test_number(heat: float, expected: String, test_parameters: Array = [
	[12.0, "12"],
	[20.4, "20.4"],
	[3.96, "4"],
]) -> void:
	assert_str(HeatText.number(heat)).is_equal(expected)


func test_summary_shows_dollars_for_heat_and_the_rate() -> void:
	var lines: Array[HeatLine] = [HeatLine.for_action(ActionKind.Kind.FULL_REVEAL, 6.0, 1.0, 1.0)]
	var summary: HandSummary = HandSummary.new(24000, lines, false)
	assert_str(HeatText.summary_text(summary)).is_equal("+$24,000 for 6 heat ($4,000 per heat)")


func test_summary_without_heat_has_no_rate() -> void:
	var lines: Array[HeatLine] = [HeatLine.for_table(HeatLine.Kind.COOLING, -2.0)]
	var summary: HandSummary = HandSummary.new(-1000, lines, true)
	assert_str(HeatText.summary_text(summary)).is_equal("-$1,000, no heat")


func test_losing_summary_rate_is_negative() -> void:
	var lines: Array[HeatLine] = [HeatLine.for_action(ActionKind.Kind.NUDGE, 4.0, 1.0, 1.0)]
	var summary: HandSummary = HandSummary.new(-2000, lines, false)
	assert_str(HeatText.summary_text(summary)).is_equal("-$2,000 for 4 heat (-$500 per heat)")


# gdlint: ignore=unused-argument
func test_tier_name(tier: HeatTier.Kind, expected: String, test_parameters: Array = [
	[HeatTier.Kind.CLEAN, "Clean"],
	[HeatTier.Kind.WATCHED, "Watched"],
	[HeatTier.Kind.MARKED, "Marked"],
	[HeatTier.Kind.BACKED_OFF, "Backed off"],
]) -> void:
	assert_str(HeatText.tier_name(tier)).is_equal(expected)


func test_cost_preview_shows_the_cost_now_when_revealed() -> void:
	var fixture: ActionsFixture = ActionsFixture.new()
	var hand: HandActions = fixture.actions(fixture.blackjack(["KS", "9H", "7D", "5C", "2S"]))
	assert_str(HeatText.cost_preview(hand, ActionKind.Kind.NUDGE, true)).is_equal("12")


func test_cost_preview_includes_the_later_window_surcharge() -> void:
	var fixture: ActionsFixture = ActionsFixture.new()
	var rnd: BlackjackRound = fixture.blackjack(["KS", "9H", "7D", "5C", "2S"])
	var hand: HandActions = fixture.actions(rnd)
	hand.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	assert_str(HeatText.cost_preview(hand, ActionKind.Kind.PARTIAL_REVEAL, true)).is_equal("3.4")


func test_cost_preview_is_hidden_without_reveal_costs() -> void:
	var fixture: ActionsFixture = ActionsFixture.new()
	var hand: HandActions = fixture.actions(fixture.blackjack(["KS", "9H", "7D", "5C", "2S"]))
	assert_str(HeatText.cost_preview(hand, ActionKind.Kind.NUDGE, false)).is_equal("")
