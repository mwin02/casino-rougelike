extends GdUnitTestSuite
## A shop stop (spec §6.4): extra hands for the next floor's clock, at most
## extra_hands_cap a floor, paid from the bankroll, never below its reserve.
## With deck services, both share one bankroll. Default config: extra hands
## 2% of the quota each, cap 10.

const QUOTA: int = 100_000
const BANKROLL: int = 50_000

var _config: TuneConfig
var _pricing: ShopPricing


func before_test() -> void:
	_config = TuneConfig.load_default()
	_pricing = ShopPricing.new(QUOTA, 100, 100)


func _stop(bankroll: int = BANKROLL, reserve: int = 0, bought: int = 0) -> ShopStop:
	return ShopStop.new(_config, _pricing, bankroll, reserve, bought)


func _services(bankroll: int) -> DeckServices:
	var rng: RandomNumberGenerator = GameRng.new(3).stream(GameRng.Stream.SHOP)
	return DeckServices.new(
		DeckRules.from_config(_config), Deck.standard(20), ActionKit.starting(), _pricing,
		bankroll, rng
	)


func test_an_extra_hand_costs_its_share_of_the_quota() -> void:
	var stop: ShopStop = _stop()
	assert_int(stop.extra_hand_price()).is_equal(2_000)
	assert_bool(stop.buy_extra_hand()).is_true()
	assert_int(stop.bankroll()).is_equal(BANKROLL - 2_000)
	assert_int(stop.extra_hands).is_equal(1)


func test_extra_hands_stop_at_the_cap_for_the_floor() -> void:
	var cap: int = _config.get_int("clock", "extra_hands_cap")
	var stop: ShopStop = _stop(BANKROLL, 0, cap - 1)
	assert_bool(stop.buy_extra_hand()).is_true()
	assert_bool(stop.can_buy_extra_hand()).is_false()
	assert_bool(stop.buy_extra_hand()).is_false()
	assert_int(stop.extra_hands).is_equal(cap)
	assert_int(stop.bankroll()).is_equal(BANKROLL - 2_000)


func test_an_unaffordable_extra_hand_is_refused_without_charging() -> void:
	var stop: ShopStop = _stop(1_999)
	assert_bool(stop.buy_extra_hand()).is_false()
	assert_int(stop.bankroll()).is_equal(1_999)


func test_nothing_is_bought_below_the_reserve() -> void:
	var stop: ShopStop = _stop(10_000, 7_000)
	assert_bool(stop.buy_extra_hand()).is_true()
	assert_bool(stop.can_buy_extra_hand()).is_false()
	assert_int(stop.bankroll()).is_equal(8_000)


func test_deck_services_respect_the_reserve() -> void:
	var services: DeckServices = _services(10_000)
	services.reserve = 6_000
	# Addition is 8%: $8,000 would leave $2,000, under the reserve.
	assert_bool(services.can_add(5)).is_false()
	assert_bool(services.add(5, Card.Suit.HEARTS)).is_false()
	assert_int(services.bankroll).is_equal(10_000)
	# Removal is 5%: $5,000 leaves $5,000, still under.
	assert_bool(services.can_remove(0)).is_false()
	services.reserve = 5_000
	assert_bool(services.remove(0)).is_true()


func test_deck_services_and_extra_hands_share_one_bankroll() -> void:
	var stop: ShopStop = ShopStop.new(_config, _pricing, 0, 1_000, 0, _services(20_000))
	assert_int(stop.bankroll()).is_equal(20_000)
	assert_bool(stop.services.remove(0)).is_true()
	assert_bool(stop.buy_extra_hand()).is_true()
	assert_int(stop.bankroll()).is_equal(13_000)
	assert_int(stop.services.bankroll).is_equal(13_000)
	assert_int(stop.services.reserve).is_equal(1_000)
