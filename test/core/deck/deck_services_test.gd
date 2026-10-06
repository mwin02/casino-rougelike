extends GdUnitTestSuite
## Deck services at a shop (spec §4.1): removal with an escalating price,
## addition and clear marks, each priced as a share of the floor quota and
## paid from the bankroll. Reforging is in deck_reforge_test. Default
## config: removal 5% +3% per earlier removal, addition 8%, clear mark 2%.

const QUOTA: int = 100_000
const BANKROLL: int = 1_000_000
const MIN_SIZE: int = 20

## Hearts are ids 26–38 in a standard deck, ace first.
const SEVEN_OF_HEARTS: int = 32

var _deck: Deck
var _kit: ActionKit
var _rules: DeckRules


func before_test() -> void:
	_rules = DeckRules.from_config(TuneConfig.load_default())
	_deck = Deck.standard(MIN_SIZE)
	_kit = ActionKit.starting()


func _shop(bankroll: int = BANKROLL, run_seed: int = 11) -> DeckServices:
	var rng: RandomNumberGenerator = GameRng.new(run_seed).stream(GameRng.Stream.SHOP)
	return DeckServices.new(_rules, _deck, _kit, QUOTA, bankroll, rng)


func _floor() -> float:
	return HeatFloor.of(_deck, _kit, _rules)


# Removal


func test_removal_price_escalates_per_removal_this_run() -> void:
	var shop: DeckServices = _shop()
	assert_int(shop.price(DeckServices.Service.REMOVE)).is_equal(5_000)
	assert_bool(shop.remove(0)).is_true()
	assert_int(shop.price(DeckServices.Service.REMOVE)).is_equal(8_000)
	assert_bool(shop.remove(1)).is_true()
	assert_int(shop.price(DeckServices.Service.REMOVE)).is_equal(11_000)
	assert_int(shop.bankroll).is_equal(BANKROLL - 13_000)


func test_removals_at_an_earlier_shop_still_escalate() -> void:
	_shop().remove(0)
	assert_int(_shop().price(DeckServices.Service.REMOVE)).is_equal(8_000)


func test_flat_removals_never_escalate() -> void:
	_kit.flat_removals = true
	var shop: DeckServices = _shop()
	shop.remove(0)
	shop.remove(1)
	assert_int(shop.price(DeckServices.Service.REMOVE)).is_equal(5_000)


func test_removal_takes_the_card_and_steps_the_floor() -> void:
	var shop: DeckServices = _shop()
	shop.remove(SEVEN_OF_HEARTS)
	assert_object(_deck.card(SEVEN_OF_HEARTS)).is_null()
	assert_float(_floor()).is_equal_approx(_rules.floor_per_removal, 0.0001)


func test_minimum_deck_size_blocks_removals_without_charging() -> void:
	var shop: DeckServices = _shop()
	_kit.flat_removals = true
	for id: int in 52 - MIN_SIZE:
		assert_bool(shop.remove(id)).is_true()
	var paid: int = shop.bankroll
	assert_bool(shop.can_remove(51)).is_false()
	assert_bool(shop.remove(51)).is_false()
	assert_int(_deck.size()).is_equal(MIN_SIZE)
	assert_int(shop.bankroll).is_equal(paid)


func test_a_missing_card_cannot_be_removed() -> void:
	var shop: DeckServices = _shop()
	shop.remove(0)
	assert_bool(shop.remove(0)).is_false()


func test_a_service_the_player_cannot_afford_is_refused() -> void:
	var shop: DeckServices = _shop(4_999)
	assert_bool(shop.can_remove(0)).is_false()
	assert_bool(shop.remove(0)).is_false()
	assert_int(_deck.size()).is_equal(52)
	assert_int(shop.bankroll).is_equal(4_999)


# Addition


func test_addition_adds_the_chosen_card_and_charges() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.add(1, Card.Suit.SPADES)).is_true()
	assert_int(_deck.size()).is_equal(53)
	assert_int(_deck.composition()["AS"]).is_equal(2)
	assert_int(shop.bankroll).is_equal(BANKROLL - 8_000)
	assert_float(_floor()).is_equal_approx(_rules.floor_per_addition, 0.0001)


func test_addition_refuses_a_bad_rank() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.can_add(14)).is_false()
	assert_bool(shop.add(14, Card.Suit.SPADES)).is_false()
	assert_int(shop.bankroll).is_equal(BANKROLL)


# Clear marks


func test_clearing_a_mark_charges_and_lowers_the_floor() -> void:
	_deck.mark(0, 0)
	_deck.mark(1, 1)
	var shop: DeckServices = _shop()
	assert_bool(shop.clear_mark(0)).is_true()
	assert_bool(_deck.card(0).is_marked()).is_false()
	assert_int(shop.bankroll).is_equal(BANKROLL - 2_000)
	assert_float(_floor()).is_equal_approx(_rules.floor_per_mark, 0.0001)


func test_an_unmarked_card_cannot_be_cleared() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.can_clear_mark(0)).is_false()
	assert_bool(shop.clear_mark(0)).is_false()
	assert_int(shop.bankroll).is_equal(BANKROLL)


func test_a_card_shown_by_an_open_rummage_cannot_be_removed() -> void:
	var shop: DeckServices = _shop()
	var shown: Card = shop.start_rummage()[0]
	assert_bool(shop.remove(shown.id)).is_false()
	shop.skip_rummage()
	assert_bool(shop.remove(shown.id)).is_true()
