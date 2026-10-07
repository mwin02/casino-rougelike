extends GdUnitTestSuite
## Reforging at a shop (spec §4.1): Rummage, Touch-up and Full reforge, and
## what counts as a small change. Prices are shares of the floor quota paid
## from the bankroll. Default config: Rummage 3% and shows 5 cards,
## Touch-up 6%, Full reforge 15%; a small change is ±1 rank.

const QUOTA: int = 100_000
const BANKROLL: int = 1_000_000
const MIN_SIZE: int = 20

## Ids in a standard deck: clubs 0–12, diamonds 13–25, hearts 26–38,
## spades 39–51, ace first.
const SEVEN_OF_HEARTS: int = 32
const ACE_OF_CLUBS: int = 0
const KING_OF_CLUBS: int = 12

var _deck: Deck
var _kit: ActionKit
var _rules: DeckRules


func before_test() -> void:
	_rules = DeckRules.from_config(TuneConfig.load_default())
	_deck = Deck.standard(MIN_SIZE)
	_kit = ActionKit.starting()


func _shop(bankroll: int = BANKROLL, run_seed: int = 11) -> DeckServices:
	var rng: RandomNumberGenerator = GameRng.new(run_seed).stream(GameRng.Stream.SHOP)
	var pricing: ShopPricing = ShopPricing.new(QUOTA, 100, 100)
	return DeckServices.new(_rules, _deck, _kit, pricing, bankroll, rng)


# Small change


func test_a_small_change_is_one_rank_or_a_new_suit() -> void:
	var seven: Card = _deck.card(SEVEN_OF_HEARTS)
	assert_bool(DeckServices.is_small_change(seven, 8, Card.Suit.HEARTS, 1)).is_true()
	assert_bool(DeckServices.is_small_change(seven, 6, Card.Suit.HEARTS, 1)).is_true()
	assert_bool(DeckServices.is_small_change(seven, 7, Card.Suit.SPADES, 1)).is_true()
	assert_bool(DeckServices.is_small_change(seven, 9, Card.Suit.HEARTS, 1)).is_false()
	assert_bool(DeckServices.is_small_change(seven, 8, Card.Suit.SPADES, 1)).is_false()
	assert_bool(DeckServices.is_small_change(seven, 7, Card.Suit.HEARTS, 1)).is_false()


func test_a_small_change_does_not_wrap() -> void:
	var king: Card = _deck.card(KING_OF_CLUBS)
	var ace: Card = _deck.card(ACE_OF_CLUBS)
	assert_bool(DeckServices.is_small_change(king, 1, Card.Suit.CLUBS, 1)).is_false()
	assert_bool(DeckServices.is_small_change(ace, 13, Card.Suit.CLUBS, 1)).is_false()
	assert_bool(DeckServices.is_small_change(king, 14, Card.Suit.CLUBS, 1)).is_false()
	assert_bool(DeckServices.is_small_change(ace, 0, Card.Suit.CLUBS, 1)).is_false()


# Rummage


func test_rummage_charges_up_front_and_shows_distinct_deck_cards() -> void:
	var shop: DeckServices = _shop()
	var offer: Array[Card] = shop.start_rummage()
	assert_int(offer.size()).is_equal(5)
	assert_int(shop.bankroll).is_equal(BANKROLL - 3_000)
	var ids: Dictionary[int, bool] = {}
	for card: Card in offer:
		assert_object(_deck.card(card.id)).is_not_null()
		ids[card.id] = true
	assert_int(ids.size()).is_equal(5)


func test_rummage_draws_the_same_cards_from_the_same_seed() -> void:
	var first: Array[int] = _ids(_shop(BANKROLL, 3).start_rummage())
	var again: Array[int] = _ids(_shop(BANKROLL, 3).start_rummage())
	var other: Array[int] = _ids(_shop(BANKROLL, 4).start_rummage())
	assert_array(again).is_equal(first)
	assert_array(other).is_not_equal(first)


func test_rummage_makes_one_small_change_to_an_offered_card() -> void:
	var shop: DeckServices = _shop()
	var card: Card = shop.start_rummage()[0]
	var new_suit: Card.Suit = ((card.suit + 1) % 4) as Card.Suit
	assert_bool(shop.rummage(card.id, card.rank, new_suit)).is_true()
	assert_int(_deck.card(card.id).suit).is_equal(new_suit)
	assert_int(_deck.edit_count(DeckEdit.Kind.REFORGE_RUMMAGE)).is_equal(1)
	assert_int(shop.bankroll).is_equal(BANKROLL - 3_000)
	assert_array(shop.rummage_offer()).is_empty()
	assert_bool(shop.rummage(card.id, card.rank, card.suit)).is_false()


func test_rummage_refuses_a_card_not_offered_or_a_big_change() -> void:
	var shop: DeckServices = _shop()
	var offer: Array[Card] = shop.start_rummage()
	var offered: Array[int] = _ids(offer)
	var outside: int = 0
	while outside in offered:
		outside += 1
	var outside_card: Card = _deck.card(outside)
	var new_suit: Card.Suit = ((outside_card.suit + 1) % 4) as Card.Suit
	assert_bool(shop.rummage(outside, outside_card.rank, new_suit)).is_false()
	var card: Card = offer[0]
	var far_rank: int = card.rank + 5 if card.rank <= 8 else card.rank - 5
	assert_bool(shop.rummage(card.id, far_rank, card.suit)).is_false()
	assert_int(shop.rummage_offer().size()).is_equal(5)


func test_skipping_a_rummage_keeps_the_charge() -> void:
	var shop: DeckServices = _shop()
	shop.start_rummage()
	shop.skip_rummage()
	assert_array(shop.rummage_offer()).is_empty()
	assert_int(shop.bankroll).is_equal(BANKROLL - 3_000)
	assert_array(_deck.edits()).is_empty()


func test_a_rummage_cannot_start_while_one_is_open_or_unaffordable() -> void:
	var shop: DeckServices = _shop()
	shop.start_rummage()
	assert_array(shop.start_rummage()).is_empty()
	assert_int(shop.bankroll).is_equal(BANKROLL - 3_000)
	assert_array(_shop(2_999).start_rummage()).is_empty()


# Touch-up and full reforge


func test_touch_up_makes_a_small_change_to_any_card() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.touch_up(SEVEN_OF_HEARTS, 8, Card.Suit.HEARTS)).is_true()
	assert_str(_deck.card(SEVEN_OF_HEARTS).short_name()).is_equal("8H")
	assert_int(shop.bankroll).is_equal(BANKROLL - 6_000)
	assert_int(_deck.edit_count(DeckEdit.Kind.REFORGE_TOUCH_UP)).is_equal(1)


func test_touch_up_refuses_a_big_change_without_charging() -> void:
	var shop: DeckServices = _shop()
	var touch_up: DeckServices.Service = DeckServices.Service.TOUCH_UP
	assert_bool(shop.can_reforge(touch_up, SEVEN_OF_HEARTS, 9, Card.Suit.HEARTS)).is_false()
	assert_bool(shop.touch_up(SEVEN_OF_HEARTS, 9, Card.Suit.HEARTS)).is_false()
	assert_bool(shop.touch_up(KING_OF_CLUBS, 1, Card.Suit.CLUBS)).is_false()
	assert_int(shop.bankroll).is_equal(BANKROLL)


func test_full_reforge_turns_a_card_into_any_card() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.full_reforge(SEVEN_OF_HEARTS, 1, Card.Suit.SPADES)).is_true()
	assert_str(_deck.card(SEVEN_OF_HEARTS).short_name()).is_equal("AS")
	assert_int(shop.bankroll).is_equal(BANKROLL - 15_000)
	assert_int(_deck.edit_count(DeckEdit.Kind.REFORGE_FULL)).is_equal(1)


func test_a_reforge_that_changes_nothing_is_refused() -> void:
	var shop: DeckServices = _shop()
	assert_bool(shop.full_reforge(SEVEN_OF_HEARTS, 7, Card.Suit.HEARTS)).is_false()
	assert_int(shop.bankroll).is_equal(BANKROLL)


func test_a_reforged_card_keeps_its_mark() -> void:
	_deck.mark(SEVEN_OF_HEARTS, 1)
	_shop().full_reforge(SEVEN_OF_HEARTS, 1, Card.Suit.SPADES)
	assert_int(_deck.card(SEVEN_OF_HEARTS).symbol).is_equal(1)


func _ids(cards: Array[Card]) -> Array[int]:
	var result: Array[int] = []
	for card: Card in cards:
		result.append(card.id)
	return result
