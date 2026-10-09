extends GdUnitTestSuite
## What a bot brings to a run and buys in it (spec §2.4, §6.4, §7.6, §9):
## the starting kit plus the unlocks its policy uses, then its wishlist.

const QUOTA: int = 140_000

var _config: TuneConfig = TuneConfig.load_default()


func _plan(bot: String) -> RunPlan:
	return BotRoster.build([bot])[0].run_plan()


## A stop holding exactly offers, for a bot with kit.
func _stop(kit: ActionKit, offers: Array[ItemKind.Kind], bankroll: int) -> ShopStop:
	var stop: ShopStop = ShopStop.new(_config, ShopPricing.new(QUOTA, 100, 100), bankroll, 0, 0)
	stop.stock(kit, ItemRules.from_config(_config), GameRng.new(1).stream(GameRng.Stream.SHOP))
	stop.offers.assign(offers)
	return stop


func test_a_bot_starts_with_the_starting_kit_and_its_own_unlocks() -> void:
	var reader: ActionKit = RunRunner.kit(_config, _plan("reader"), [])
	assert_bool(reader.has(ActionKind.Kind.FULL_REVEAL)).is_true()
	assert_bool(reader.has(ActionKind.Kind.PALM)).is_false()
	assert_array(reader.items).contains_exactly([ItemKind.Kind.SHADED_LENSES])
	var mechanic: ActionKit = RunRunner.kit(_config, _plan("manipulate_max"), [])
	assert_bool(mechanic.has(ActionKind.Kind.PALM)).is_true()
	var flat: ActionKit = RunRunner.kit(_config, _plan("straight_flat"), [])
	assert_array(flat.items).is_empty()
	assert_bool(flat.has(ActionKind.Kind.PARTIAL_REVEAL)).is_true()


func test_given_items_join_the_kit() -> void:
	var items: Array[ItemKind.Kind] = [ItemKind.Kind.HIGH_ROLLERS_NERVE]
	var kit: ActionKit = RunRunner.kit(_config, _plan("whale"), items)
	assert_array(kit.items).contains_exactly(
		[ItemKind.Kind.SHADED_LENSES, ItemKind.Kind.HIGH_ROLLERS_NERVE]
	)


func test_a_bot_buys_its_wishlist_in_order() -> void:
	var plan: RunPlan = _plan("whale")
	var kit: ActionKit = RunRunner.kit(_config, plan, [])
	var wanted: Array[ItemKind.Kind] = plan.wishlist
	var stop: ShopStop = _stop(kit, [ItemKind.Kind.MIRROR_RING, wanted[1], wanted[0]], 1_000_000)
	RunRunner.shop(stop, plan, 0)
	assert_bool(kit.has_item(wanted[0])).is_true()
	assert_bool(kit.has_item(wanted[1])).is_true()
	assert_bool(kit.has_item(ItemKind.Kind.MIRROR_RING)).is_false()


func test_a_bot_keeps_what_it_holds_back() -> void:
	var plan: RunPlan = _plan("whale")
	var kit: ActionKit = RunRunner.kit(_config, plan, [])
	var wanted: ItemKind.Kind = plan.wishlist[0]
	var stop: ShopStop = _stop(kit, [wanted], 100_000)
	var price: int = stop.item_price(wanted)
	RunRunner.shop(stop, plan, 100_000 - price + 1)
	assert_bool(kit.has_item(wanted)).is_false()
	RunRunner.shop(stop, plan, 100_000 - price)
	assert_bool(kit.has_item(wanted)).is_true()
	assert_int(stop.bankroll()).is_equal(100_000 - price)


## Mid-floor a bot spends only past its cash-out share; at the end shop it
## keeps a share of the next quota.
func test_what_a_bot_holds_back() -> void:
	var plan: RunPlan = _plan("reader")
	var quotas: Array[int] = _config.get_int_list("floors", "quotas")
	assert_int(RunRunner.holdback(_config, plan, QUOTA, 1, false)).is_equal(
		QUOTA * plan.cash_out_pct / 100
	)
	assert_int(RunRunner.holdback(_config, plan, QUOTA, 1, true)).is_equal(
		quotas[1] * RunRunner.KEEP_NEXT_QUOTA_PCT / 100
	)


## The sweep takes the item the bot values least: off its wishlist, then
## the wishlist's tail, never its own unlock while anything else is left.
func test_the_sweep_takes_the_least_valued_item() -> void:
	var plan: RunPlan = _plan("whale")
	var wanted: Array[ItemKind.Kind] = plan.wishlist
	var choices: Array[SweepChoice] = [
		SweepChoice.of_item(ItemKind.Kind.SHADED_LENSES),
		SweepChoice.of_item(wanted[0]),
		SweepChoice.of_item(wanted[1]),
	]
	assert_int(plan.sweep_choice(choices).item).is_equal(wanted[1])
	choices.append(SweepChoice.of_item(ItemKind.Kind.SLEIGHT))
	assert_int(plan.sweep_choice(choices).item).is_equal(ItemKind.Kind.SLEIGHT)
	var unlock_only: Array[SweepChoice] = [SweepChoice.of_item(ItemKind.Kind.SHADED_LENSES)]
	assert_int(plan.sweep_choice(unlock_only).item).is_equal(ItemKind.Kind.SHADED_LENSES)


func test_each_archetype_lists_items_to_buy() -> void:
	for name: String in ["reader", "whale"]:
		assert_array(_plan(name).wishlist).is_not_empty()


func _low_node() -> MapNode:
	var node: MapNode = MapNode.new(1, 0, MapNode.Kind.TABLES)
	node.tables.append(Table.new(GameKind.Kind.BLACKJACK, TableStakes.Kind.LOW, 1, 1000, 4000))
	return node


## Good players save their hands for the payoff: at a low-stakes node they
## sit only when the bankroll can't cover the floor's high stakes.
func test_good_bots_skip_low_stakes_they_can_rise_above() -> void:
	var high_min: int = _config.get_int_list("floors", "high_stakes_min")[0]
	for name: String in ["reader", "whale", "mechanic"]:
		var plan: RunPlan = _plan(name)
		assert_bool(plan.sits_at(_low_node(), high_min, high_min)).is_false()
		assert_bool(plan.sits_at(_low_node(), high_min - 1, high_min)).is_true()
	for name: String in ["straight_flat", "reveal_adjust", "marker", "stacker"]:
		assert_bool(_plan(name).sits_at(_low_node(), high_min, high_min)).is_true()
