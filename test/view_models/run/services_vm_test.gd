extends GdUnitTestSuite
## Deck services on screen (block U4, spec §4.1, §4.2), on floor 1 (quota
## $140,000) with $96,500 and a standard deck. Prices are shares of the
## quota: Rummage 3%, Touch-up 6%, Full reforge 15%, removal 5% (then 8%),
## addition 8%, clearing a mark 2%. Each edit adds 3 to the heat floor.

const PATH: String = "user://test_services_vm.bin"

var _f: RunFixture
var _deck: Deck
var _vm: ServicesVM


func before_test() -> void:
	_f = RunFixture.new(PATH, 96_500)
	_f.enter_deck_services()
	_deck = _f.owner.run.game.deck
	_vm = ServicesVM.new(_f.owner, _f.floor.services)


func after_test() -> void:
	_f.clear()


func _id(code: String) -> int:
	var wanted: Card = Card.parse(code)
	for card: Card in _deck.cards():
		if card.rank == wanted.rank and card.suit == wanted.suit:
			return card.id
	return ServicesVM.NONE


func _labels(choices: Array[Choice]) -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in choices:
		labels.append(choice.label)
	return labels


func _row(service: DeckServices.Service) -> ServiceRow:
	for row: ServiceRow in _vm.services():
		if row.service == service:
			return row
	return null


func test_the_screen_is_deck_services() -> void:
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.DECK_SERVICES)
	assert_str(_vm.deck_text()).is_equal("DECK 52")
	assert_str(_vm.money().bankroll_text()).is_equal("$96,500")
	assert_str(_vm.preview().title).is_equal("Pick a service")


func test_the_list_prices_every_service_at_this_floor() -> void:
	var names: Array[String] = []
	var prices: Array[String] = []
	for row: ServiceRow in _vm.services():
		names.append(row.name)
		prices.append(row.price_text)
	assert_array(names).contains_exactly([
		"Rummage", "Touch-up", "Full reforge", "Remove a card", "Add a card", "Clear marks",
	])
	assert_array(prices).contains_exactly([
		"$4,200", "$8,400", "$21,000", "$7,000", "$11,200", "$2,800",
	])
	assert_str(_row(DeckServices.Service.CLEAR_MARK).unit).is_equal("PER MARKED CARD")
	assert_str(_row(DeckServices.Service.REMOVE).note).is_equal(
		"Dearer each time · deck minimum 20"
	)


func test_a_service_with_nothing_to_work_on_is_off() -> void:
	assert_bool(_row(DeckServices.Service.CLEAR_MARK).enabled).is_false()
	_deck.mark(_id("AS"), 0)
	assert_bool(_row(DeckServices.Service.CLEAR_MARK).enabled).is_true()
	assert_str(_row(DeckServices.Service.CLEAR_MARK).note).is_equal(
		"1 marked · lowers the heat floor"
	)


func test_a_service_the_bankroll_cant_cover_is_off() -> void:
	_f.floor.services.bankroll = 10_000
	assert_bool(_row(DeckServices.Service.FULL_REFORGE).enabled).is_false()
	assert_bool(_row(DeckServices.Service.TOUCH_UP).enabled).is_true()


func test_a_touch_up_is_one_rank_or_a_new_suit() -> void:
	_vm.select(DeckServices.Service.TOUCH_UP)
	assert_bool(_row(DeckServices.Service.TOUCH_UP).selected).is_true()
	assert_str(_vm.preview().title).is_equal("Touch-up: pick a card")
	assert_int(_vm.cards().size()).is_equal(52)
	_vm.pick_card(_id("7S"))
	assert_str(_vm.preview().title).is_equal("Touch-up: choose the change")
	assert_array(_labels(_vm.rank_options())).contains_exactly(["6", "8"])
	assert_array(_labels(_vm.suit_options())).contains_exactly(["Hearts", "Clubs", "Diamonds"])
	assert_bool(_vm.preview().can_confirm).is_false()


func test_a_touch_up_previews_the_card_the_floor_and_the_bankroll() -> void:
	_vm.select(DeckServices.Service.TOUCH_UP)
	_vm.pick_card(_id("7S"))
	_vm.choose_rank(8)
	var view: ServicePreview = _vm.preview()
	assert_str(view.title).is_equal("Touch-up: confirm")
	assert_int(view.before.rank).is_equal(7)
	assert_int(view.after.rank).is_equal(8)
	assert_int(view.after.suit).is_equal(Card.Suit.SPADES)
	assert_str(view.floor_before_text).is_equal("0")
	assert_str(view.floor_after_text).is_equal("3")
	assert_str(view.confirm_label).is_equal("Reforge")
	assert_str(view.price_text).is_equal("$8,400")
	assert_bool(view.can_confirm).is_true()
	assert_str(view.after_text).is_equal("BANKROLL $88,100 · $51,900 SHORT")


func test_a_small_change_is_rank_or_suit_never_both() -> void:
	_vm.select(DeckServices.Service.TOUCH_UP)
	_vm.pick_card(_id("7S"))
	_vm.choose_rank(8)
	_vm.choose_suit(Card.Suit.HEARTS)
	var view: ServicePreview = _vm.preview()
	assert_int(view.after.rank).is_equal(7)
	assert_int(view.after.suit).is_equal(Card.Suit.HEARTS)
	assert_bool(view.can_confirm).is_true()


func test_confirming_a_touch_up_pays_edits_the_deck_and_saves() -> void:
	var id: int = _id("7S")
	_vm.select(DeckServices.Service.TOUCH_UP)
	_vm.pick_card(id)
	_vm.choose_rank(8)
	_vm.confirm()
	assert_int(_deck.card(id).rank).is_equal(8)
	assert_str(_vm.money().bankroll_text()).is_equal("$88,100")
	assert_int(_vm.selected()).is_equal(DeckServices.Service.TOUCH_UP)
	assert_int(_vm.picked_id()).is_equal(ServicesVM.NONE)
	assert_str(_vm.preview().floor_before_text).is_equal("3")
	var saved: Run = _f.saved()
	assert_int(saved.game.deck.card(id).rank).is_equal(8)
	assert_int(saved.floor.services.bankroll).is_equal(88_100)


func test_a_full_reforge_takes_any_rank_and_suit() -> void:
	_vm.select(DeckServices.Service.FULL_REFORGE)
	var id: int = _id("3C")
	_deck.mark(id, 0)
	_vm.pick_card(id)
	assert_int(_vm.rank_options().size()).is_equal(13)
	assert_int(_vm.suit_options().size()).is_equal(4)
	assert_bool(_vm.preview().can_confirm).is_false()
	_vm.choose_rank(1)
	_vm.choose_suit(Card.Suit.HEARTS)
	var view: ServicePreview = _vm.preview()
	assert_int(view.after.rank).is_equal(1)
	assert_int(view.after.suit).is_equal(Card.Suit.HEARTS)
	assert_int(view.after.symbol).is_equal(0)
	assert_str(view.price_text).is_equal("$21,000")
	_vm.confirm()
	assert_int(_deck.card(id).rank).is_equal(1)
	assert_int(_deck.card(id).suit).is_equal(Card.Suit.HEARTS)
	assert_int(_deck.card(id).symbol).is_equal(0)


func test_removing_a_card_shrinks_the_deck_and_the_next_costs_more() -> void:
	_vm.select(DeckServices.Service.REMOVE)
	_vm.pick_card(_id("2D"))
	var view: ServicePreview = _vm.preview()
	assert_str(view.title).is_equal("Remove a card: confirm")
	assert_str(view.confirm_label).is_equal("Remove")
	assert_object(view.after).is_null()
	assert_str(view.floor_after_text).is_equal("3")
	_vm.confirm()
	assert_str(_vm.deck_text()).is_equal("DECK 51")
	assert_int(_id("2D")).is_equal(ServicesVM.NONE)
	assert_str(_row(DeckServices.Service.REMOVE).price_text).is_equal("$11,200")


func test_adding_a_card_needs_its_rank_chosen() -> void:
	_vm.select(DeckServices.Service.ADD)
	assert_str(_vm.preview().title).is_equal("Add a card: choose the card")
	assert_array(_vm.cards()).is_empty()
	assert_int(_vm.rank_options().size()).is_equal(13)
	assert_bool(_vm.preview().can_confirm).is_false()
	_vm.choose_rank(1)
	_vm.choose_suit(Card.Suit.HEARTS)
	var view: ServicePreview = _vm.preview()
	assert_object(view.before).is_null()
	assert_int(view.after.rank).is_equal(1)
	assert_str(view.confirm_label).is_equal("Add")
	_vm.confirm()
	assert_str(_vm.deck_text()).is_equal("DECK 53")
	assert_str(_vm.money().bankroll_text()).is_equal("$85,300")


func test_clearing_a_mark_picks_only_marked_cards_and_lowers_the_floor() -> void:
	var marked: int = _id("AS")
	_deck.mark(marked, 0)
	_vm.select(DeckServices.Service.CLEAR_MARK)
	assert_bool(_vm.can_pick(marked)).is_true()
	assert_bool(_vm.can_pick(_id("KS"))).is_false()
	_vm.pick_card(_id("KS"))
	assert_int(_vm.picked_id()).is_equal(ServicesVM.NONE)
	_vm.pick_card(marked)
	var view: ServicePreview = _vm.preview()
	assert_str(view.floor_before_text).is_equal("1")
	assert_str(view.floor_after_text).is_equal("0")
	_vm.confirm()
	assert_bool(_deck.card(marked).is_marked()).is_false()
	assert_str(_vm.money().bankroll_text()).is_equal("$93,700")


func test_a_rummage_is_paid_when_its_cards_are_shown() -> void:
	_vm.select(DeckServices.Service.RUMMAGE)
	var view: ServicePreview = _vm.preview()
	assert_str(view.title).is_equal("Rummage: show 5 cards")
	assert_str(view.confirm_label).is_equal("Show cards")
	assert_str(view.price_text).is_equal("$4,200")
	assert_bool(view.can_confirm).is_true()
	_vm.confirm()
	assert_bool(_vm.rummage_open()).is_true()
	assert_str(_vm.money().bankroll_text()).is_equal("$92,300")
	assert_int(_vm.cards().size()).is_equal(5)
	assert_str(_vm.preview().title).is_equal("Rummage: pick a card")
	assert_str(_vm.preview().price_text).is_empty()
	assert_bool(_f.saved().floor.services.rummage_offer().size() == 5).is_true()


func test_an_open_rummage_takes_one_small_change_and_closes() -> void:
	_vm.select(DeckServices.Service.RUMMAGE)
	_vm.confirm()
	var shown: CardView = _vm.cards()[0]
	_vm.select(DeckServices.Service.REMOVE)
	assert_int(_vm.selected()).is_equal(DeckServices.Service.RUMMAGE)
	_vm.pick_card(shown.id)
	assert_int(_vm.suit_options().size()).is_equal(3)
	var suit: int = _vm.suit_options()[0].id
	_vm.choose_suit(suit)
	assert_str(_vm.preview().confirm_label).is_equal("Change")
	_vm.confirm()
	assert_bool(_vm.rummage_open()).is_false()
	assert_int(_deck.card(shown.id).suit).is_equal(suit)
	assert_str(_vm.money().bankroll_text()).is_equal("$92,300")
	assert_int(_vm.selected()).is_equal(ServicesVM.NONE)


func test_skipping_a_rummage_keeps_the_fee() -> void:
	_vm.select(DeckServices.Service.RUMMAGE)
	_vm.confirm()
	_vm.cancel()
	assert_bool(_vm.rummage_open()).is_false()
	assert_str(_vm.money().bankroll_text()).is_equal("$92,300")
	assert_int(_deck.edits().size()).is_equal(0)


func test_a_run_resumed_with_a_rummage_open_is_still_in_it() -> void:
	_vm.select(DeckServices.Service.RUMMAGE)
	_vm.confirm()
	var resumed: ServicesVM = ServicesVM.new(_f.owner, _f.floor.services)
	assert_int(resumed.selected()).is_equal(DeckServices.Service.RUMMAGE)
	assert_int(resumed.cards().size()).is_equal(5)


func test_cancel_puts_the_service_away() -> void:
	_vm.select(DeckServices.Service.TOUCH_UP)
	_vm.pick_card(_id("7S"))
	_vm.cancel()
	assert_int(_vm.selected()).is_equal(ServicesVM.NONE)
	assert_array(_vm.cards()).is_empty()
	assert_str(_vm.money().bankroll_text()).is_equal("$96,500")


func test_leaving_banks_the_spending_and_goes_back_to_the_map() -> void:
	_vm.select(DeckServices.Service.REMOVE)
	_vm.pick_card(_id("2D"))
	_vm.confirm()
	_vm.leave()
	assert_int(_f.owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_f.owner.run.state.bankroll).is_equal(89_500)
