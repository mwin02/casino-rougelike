extends GdUnitTestSuite
## The heat receipt on the real table (spec §1.4): one row per action with
## its final heat in whole numbers, side-bet heat folded into its action,
## the multiplier as its own Bet size row, and cooling as its own row.


func _nudge(heat: float) -> HeatLine:
	return HeatLine.for_action(ActionKind.Kind.NUDGE, heat, 1.0, 1.0)


func _labels(receipt: HeatReceipt) -> Array[String]:
	var labels: Array[String] = []
	for row: HeatReceipt.Row in receipt.rows:
		labels.append("%s %s" % [row.label, row.amount_text()])
	return labels


func test_bet_size_is_its_own_row_when_the_bet_grew() -> void:
	var lines: Array[HeatLine] = [_nudge(12.0), HeatLine.for_multiplier(2.0, 1.5, 12.0)]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +12", "Bet size +6"])
	assert_int(receipt.total).is_equal(18)


func test_no_bet_size_row_at_an_unchanged_bet() -> void:
	var lines: Array[HeatLine] = [_nudge(12.0), HeatLine.for_multiplier(1.0, 1.0, 12.0)]
	assert_array(_labels(HeatReceipt.new(lines))).contains_exactly(["Nudge +12"])


func test_no_bet_size_row_when_it_would_show_zero() -> void:
	var lines: Array[HeatLine] = [_nudge(2.0), HeatLine.for_multiplier(1.25, 1.125, 2.0)]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +2"])
	assert_int(receipt.total).is_equal(2)


func test_rows_sum_to_the_total_with_a_bet_size_row() -> void:
	# 3.4 + 3.4 + 3.4 shows as 3 + 3 + 3, and the total is what the rows show.
	var lines: Array[HeatLine] = [
		_nudge(3.4), _nudge(3.4), HeatLine.for_multiplier(2.0, 1.5, 6.8),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +3", "Nudge +3", "Bet size +3"])
	assert_int(receipt.total).is_equal(9)


func test_rows_sum_to_the_total_at_an_unchanged_bet() -> void:
	var lines: Array[HeatLine] = [
		_nudge(3.4), _nudge(3.4), HeatLine.for_multiplier(1.0, 1.0, 6.8),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +3", "Nudge +3"])
	assert_int(receipt.total).is_equal(6)


func test_bet_size_is_never_negative() -> void:
	# Three rows round up by 1.5 in all; the multiplier adds under 0.4.
	var lines: Array[HeatLine] = [
		_nudge(2.5), _nudge(2.5), _nudge(2.5), HeatLine.for_multiplier(1.1, 1.05, 7.5),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +3", "Nudge +3", "Nudge +3"])
	assert_int(receipt.total).is_equal(9)


func test_side_bet_heat_stays_out_of_bet_size() -> void:
	# Spec §1.4, §8: the multiplier is on the Nudge's 12, not its side-bet heat.
	var lines: Array[HeatLine] = [
		_nudge(12.0), HeatLine.for_side_bet(24.4, 1.0), HeatLine.for_multiplier(2.0, 1.5, 12.0),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +36", "Bet size +6"])
	assert_int(receipt.total).is_equal(42)


func test_a_real_hands_side_bet_heat_lands_on_its_manipulation() -> void:
	# Player 7H and 8D with Perfect Pairs on; nudging 8D down pairs them.
	var fixture: ActionsFixture = ActionsFixture.new()
	fixture.side_bets = [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, 1000)]
	var hand: HandActions = fixture.actions(fixture.blackjack(["7H", "5S", "8D", "9C", "2S"]))
	var cost: float = hand.nudge_cost(2, -1)
	hand.nudge(2, -1)
	assert_int(hand.heat.lines.size()).is_equal(2)
	var receipt: HeatReceipt = HeatReceipt.new(hand.heat.lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +%d" % roundi(cost)])


func test_a_bigger_bet_never_changes_an_action_row() -> void:
	var flat: Array[HeatLine] = [_nudge(12.0), HeatLine.for_multiplier(1.0, 1.0, 12.0)]
	var doubled: Array[HeatLine] = [_nudge(12.0), HeatLine.for_multiplier(2.0, 1.5, 12.0)]
	assert_int(HeatReceipt.new(doubled).rows[0].amount).is_equal(HeatReceipt.new(flat).rows[0].amount)


func test_side_bet_heat_is_folded_into_its_action() -> void:
	var lines: Array[HeatLine] = [
		_nudge(12.0), HeatLine.for_side_bet(24.4, 1.0), HeatLine.for_multiplier(1.0, 1.0, 12.0),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Nudge +36"])
	assert_int(receipt.total).is_equal(36)


func test_bet_changes_say_which_way_the_bet_moved() -> void:
	var lines: Array[HeatLine] = [
		HeatLine.for_bet_change(BetChange.Kind.ADJUST, 7.0, 1.0, 2000),
		HeatLine.for_bet_change(BetChange.Kind.ADJUST, 7.0, 1.0, -500),
		HeatLine.for_bet_change(BetChange.Kind.SIDE_SWITCH, 7.0, 1.0),
	]
	assert_array(_labels(HeatReceipt.new(lines))).contains_exactly(
		["Raised bet +7", "Lowered bet +7", "Side switch +7"]
	)


func test_cooling_is_its_own_row_outside_the_hand_total() -> void:
	var lines: Array[HeatLine] = [
		HeatLine.for_multiplier(1.0, 1.0, 0.0), HeatLine.for_table(HeatLine.Kind.COOLING, -6.2),
	]
	var receipt: HeatReceipt = HeatReceipt.new(lines)
	assert_array(_labels(receipt)).contains_exactly(["Straight hand -6"])
	assert_int(receipt.total).is_equal(0)


func test_cooling_too_small_to_show_has_no_row() -> void:
	var lines: Array[HeatLine] = [HeatLine.for_table(HeatLine.Kind.COOLING, -0.2)]
	assert_array(HeatReceipt.new(lines).rows).is_empty()


func test_what_the_table_did_is_kept_as_notices() -> void:
	var tier: HeatLine = HeatLine.for_table(HeatLine.Kind.TIER)
	tier.tier = HeatTier.Kind.MARKED
	var consequence: HeatLine = HeatLine.for_table(HeatLine.Kind.CONSEQUENCE)
	consequence.consequence = MarkedConsequence.Kind.HOUSE_DECK_SWAP
	var lines: Array[HeatLine] = [_nudge(50.0), tier, consequence]
	assert_array(HeatReceipt.new(lines).notices).contains_exactly(
		["Table is now Marked", "The pit swaps in a house deck."]
	)


func test_no_row_shows_how_its_heat_was_made_up() -> void:
	# Spec §1.4: a later window, a hot tier and a raised bet, all at once.
	var lines: Array[HeatLine] = [
		HeatLine.for_action(ActionKind.Kind.NUDGE, 12.0, 1.7, 1.5),
		HeatLine.for_side_bet(16.3, 1.5),
		HeatLine.for_bet_change(BetChange.Kind.ADJUST, 7.0, 1.5, 1000),
		HeatLine.for_multiplier(2.0, 1.5, 41.1),
	]
	for text: String in _labels(HeatReceipt.new(lines)):
		assert_bool(RegEx.create_from_string("[×x(]|\\d\\.\\d").search(text) == null).is_true()
