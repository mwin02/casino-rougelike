extends GdUnitTestSuite
## Sanity check (BUILD_PLAN block 8): the prototype's findings reproduce
## under the old rules. Prototype finding 1: flat-priced High or Low, where
## every correct call pays even money whatever the odds, hands the player a
## large edge (+44% there) for just calling the likelier side. Here every
## call is set to double the chain (200%); the same bot loses under the spec's
## pricing (§3.3).

const FLAT_PRICING: Array[String] = [
	"--set=high_low.min_call_payout_pct=200", "--set=high_low.max_call_payout_pct=200"
]


func _greedy(extra: Array[String]) -> SimReport.Record:
	var args: Array[String] = [
		"--sessions=100", "--hands=20", "--seed=3", "--games=high_low", "--bots=high_low_greedy"
	]
	args.append_array(extra)
	var report: SimReport = SimRun.dollars_per_heat(SimOptions.parse(PackedStringArray(args)))
	return report.record(0, GameKind.Kind.HIGH_LOW, "high_low_greedy")


func test_flat_priced_high_or_low_shows_a_large_player_edge() -> void:
	var record: SimReport.Record = _greedy(FLAT_PRICING)
	assert_float(record.edge()).is_greater(0.25)
	assert_float(record.heat_per_hand()).is_equal(0.0)


func test_priced_high_or_low_keeps_the_house_edge() -> void:
	assert_float(_greedy([]).edge()).is_less(0.0)
