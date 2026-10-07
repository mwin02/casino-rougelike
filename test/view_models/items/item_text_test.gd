extends GdUnitTestSuite
## Item text on the debug screen (spec §9): a hand's item bonuses, and what
## the Pit Ledger shows of a table.


func test_bonus_lines_name_the_item_and_its_dollars() -> void:
	var bonuses: Array[ItemBonus] = [
		ItemBonus.new(ItemKind.Kind.SIGNATURE, 250),
		ItemBonus.new(ItemKind.Kind.COMP_SLIP, 1000),
	]
	assert_array(ItemText.bonus_lines(bonuses)).contains_exactly(
		["Signature +$250", "Comp Slip +$1,000"]
	)


func test_the_ledger_shows_every_cost_and_the_consequence() -> void:
	var rules: HeatRules = HeatRules.from_config(TuneConfig.load_default())
	var costs: TableCosts = TableCosts.centered(rules, GameKind.Kind.BLACKJACK)
	var ledger: PitLedger = PitLedger.new(costs, MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	assert_str(ItemText.ledger_text(ledger)).is_equal(
		"Pit Ledger: Partial reveal 2, Mark 3, Full reveal 4, Look ahead 7, Recolour 10,"
		+ " Nudge 12, Switch 20, Palm 28; if Marked, house deck swap"
	)
