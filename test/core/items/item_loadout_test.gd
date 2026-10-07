extends GdUnitTestSuite
## Items in the loadout (spec §9): six slots, one of each item, and each
## item's effect through the kit. Unlocks gate their actions; symbol items
## add symbols; the rest change what the kit tells the rules. The kit starts
## as the spec's starting kit (§2.4). Card i has id i.

## Player 2 and 3, dealer 9 up and 7 in the hole (id 3); hits deal 4, 5, 6.
const HITS: Array[String] = ["2", "9", "3", "7", "4", "5", "6"]

var _f: ActionsFixture
var _rules: ItemRules


func before_test() -> void:
	_f = ActionsFixture.new()
	_f.kit = ActionKit.starting()
	_rules = ItemRules.from_config(_f.config)


func _add(item: ItemKind.Kind) -> bool:
	return _f.kit.add_item(item, _rules)


# Slots


func test_six_slots_refuse_a_seventh_item() -> void:
	var items: Array[ItemKind.Kind] = [
		ItemKind.Kind.SHADED_LENSES,
		ItemKind.Kind.MIRROR_RING,
		ItemKind.Kind.DYED_THUMB,
		ItemKind.Kind.MECHANICS_GRIP,
		ItemKind.Kind.COLD_DECK,
		ItemKind.Kind.WAX_PENCIL,
	]
	for item: ItemKind.Kind in items:
		assert_bool(_add(item)).is_true()
	assert_int(_rules.slots).is_equal(6)
	assert_bool(_f.kit.has_free_slot(_rules)).is_false()
	assert_bool(_add(ItemKind.Kind.GREASE_PENCIL)).is_false()
	assert_bool(_f.kit.has_item(ItemKind.Kind.GREASE_PENCIL)).is_false()


func test_one_of_each_item() -> void:
	assert_bool(_add(ItemKind.Kind.SLEIGHT)).is_true()
	assert_bool(_add(ItemKind.Kind.SLEIGHT)).is_false()
	assert_int(_f.kit.items.size()).is_equal(1)


func test_discarding_frees_the_slot_and_drops_the_effect() -> void:
	_add(ItemKind.Kind.SHADED_LENSES)
	assert_bool(_f.kit.remove_item(ItemKind.Kind.SHADED_LENSES)).is_true()
	assert_bool(_f.kit.has(ActionKind.Kind.FULL_REVEAL)).is_false()
	assert_array(_f.kit.items).is_empty()
	assert_bool(_f.kit.remove_item(ItemKind.Kind.SHADED_LENSES)).is_false()


func test_every_item_has_a_rarity() -> void:
	assert_int(ItemKind.Kind.size()).is_equal(26)
	for item: ItemKind.Kind in ItemKind.Kind.values():
		assert_bool(ItemKind.RARITY.has(item)).is_true()


# Unlocks and symbols


func test_unlock_items_gate_their_actions(
	item: ItemKind.Kind,
	action: ActionKind.Kind,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[ItemKind.Kind.SHADED_LENSES, ActionKind.Kind.FULL_REVEAL],
		[ItemKind.Kind.MIRROR_RING, ActionKind.Kind.LOOK_AHEAD],
		[ItemKind.Kind.DYED_THUMB, ActionKind.Kind.RECOLOUR],
		[ItemKind.Kind.MECHANICS_GRIP, ActionKind.Kind.SWITCH],
		[ItemKind.Kind.COLD_DECK, ActionKind.Kind.PALM],
	]
) -> void:
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	assert_bool(actions.can_use(action)).is_false()
	_add(item)
	assert_bool(actions.can_use(action)).is_true()


func test_the_starting_kit_keeps_its_three_actions() -> void:
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	assert_bool(actions.can_use(ActionKind.Kind.PARTIAL_REVEAL)).is_true()
	assert_bool(actions.can_use(ActionKind.Kind.NUDGE)).is_true()
	assert_bool(actions.can_use(ActionKind.Kind.MARK)).is_true()


func test_symbol_items_each_add_a_symbol(
	item: ItemKind.Kind,
	symbol: int,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		[ItemKind.Kind.WAX_PENCIL, 2],
		[ItemKind.Kind.GREASE_PENCIL, 3],
		[ItemKind.Kind.LUMINOUS_INK, 4],
	]
) -> void:
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	assert_bool(actions.mark(0, symbol)).is_false()
	_add(item)
	assert_bool(actions.mark(0, symbol)).is_true()


func test_a_symbol_keeps_its_id_when_another_symbol_item_goes() -> void:
	_add(ItemKind.Kind.WAX_PENCIL)
	_add(ItemKind.Kind.GREASE_PENCIL)
	_f.kit.remove_item(ItemKind.Kind.WAX_PENCIL)
	assert_array(_f.kit.symbols).contains_exactly([0, 1, 3])


func test_luminous_ink_marks_add_half_to_the_floor() -> void:
	_add(ItemKind.Kind.LUMINOUS_INK)
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	var deck_rules: DeckRules = DeckRules.from_config(_f.config)
	var before: float = HeatFloor.of(_f.deck, _f.kit, deck_rules)
	actions.mark(0, 4)
	actions.mark(1, 0)
	var expected: float = deck_rules.floor_per_luminous_mark + deck_rules.floor_per_mark
	var added: float = HeatFloor.of(_f.deck, _f.kit, deck_rules) - before
	assert_float(added).is_equal_approx(expected, 0.0001)


# Heat and information


func test_loaded_question_asks_two_questions() -> void:
	var asked: Array[PartialQuestion.Kind] = [
		PartialQuestion.Kind.TEN_CARD, PartialQuestion.Kind.RED
	]
	var actions: HandActions = _f.actions(_f.blackjack(HITS))
	assert_array(actions.partial_reveal(3, asked)).is_empty()
	_add(ItemKind.Kind.LOADED_QUESTION)
	assert_array(actions.partial_reveal(3, asked)).contains_exactly([false, false])


func test_deep_read_removes_the_second_window_surcharge() -> void:
	_add(ItemKind.Kind.DEEP_READ)
	var rnd: BlackjackRound = _f.blackjack(HITS)
	var actions: HandActions = _f.actions(rnd)
	actions.partial_reveal(3, [PartialQuestion.Kind.RED])
	rnd.proceed()
	rnd.proceed()
	rnd.hit()
	actions.partial_reveal(4, [PartialQuestion.Kind.RED])
	var center: float = _f.heat_rules.center(GameKind.Kind.BLACKJACK, ActionKind.Kind.PARTIAL_REVEAL)
	assert_float(actions.heat.total()).is_equal(2.0 * center)


# Deck


func test_forged_papers_cuts_the_floor() -> void:
	var deck: Deck = Deck.standard(20)
	for id: int in 12:
		deck.mark(id, 0)
	var deck_rules: DeckRules = DeckRules.from_config(_f.config)
	_add(ItemKind.Kind.FORGED_PAPERS)
	var expected: float = 12 * deck_rules.floor_per_mark - deck_rules.forged_papers_floor_cut
	assert_float(HeatFloor.of(deck, _f.kit, deck_rules)).is_equal_approx(expected, 0.0001)


func test_second_deck_makes_removals_a_flat_price() -> void:
	var deck: Deck = Deck.standard(20)
	var rng: RandomNumberGenerator = GameRng.new(1).stream(GameRng.Stream.SHOP)
	var services: DeckServices = DeckServices.new(
		DeckRules.from_config(_f.config), deck, _f.kit, ShopPricing.new(100_000, 100, 100),
		1_000_000, rng
	)
	_add(ItemKind.Kind.SECOND_DECK)
	var first: int = services.price(DeckServices.Service.REMOVE)
	services.remove(0)
	services.remove(1)
	assert_int(services.price(DeckServices.Service.REMOVE)).is_equal(first)
