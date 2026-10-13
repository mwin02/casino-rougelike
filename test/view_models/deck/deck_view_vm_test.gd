extends GdUnitTestSuite
## The deck screen (spec §4.4): every card in the owned deck as it deals
## now, with its symbol, its tape (§2.3) and the look of its last permanent
## change (§4.1). This hand's changes don't show. Standard deck ids run
## clubs, diamonds, hearts, spades, ace to king: 9H is 34.

const MIN_SIZE: int = 20

var _deck: Deck
var _layer: ManipulationLayer
var _kit: ActionKit
var _vm: DeckViewVM


func before_test() -> void:
	_deck = Deck.standard(MIN_SIZE)
	_layer = ManipulationLayer.new()
	_kit = ActionKit.starting()
	_vm = DeckViewVM.new(_deck, _layer, _kit)


func _id_of(code: String) -> int:
	for card: Card in _deck.cards():
		if card.short_name() == code:
			return card.id
	return Card.NO_ID


func _view(id: int) -> CardView:
	for view: CardView in _vm.cards():
		if view.id == id:
			return view
	return null


func _row_text(suit: Card.Suit) -> String:
	var ranks: PackedStringArray = []
	for view: CardView in _vm.row(suit):
		ranks.append(view.rank_text())
	return " ".join(ranks)


func _tape(id: int, rank: int, suit: Card.Suit) -> void:
	_layer.change(id, rank, suit)
	_layer.tape(id)
	_layer.end_hand()


func test_a_standard_deck_lists_every_card_plain_in_suit_rows() -> void:
	assert_int(_vm.cards().size()).is_equal(52)
	for suit: Card.Suit in Card.Suit.values():
		assert_str(_row_text(suit)).is_equal("A 2 3 4 5 6 7 8 9 10 J Q K")
		for view: CardView in _vm.row(suit):
			assert_int(view.suit).is_equal(suit)
	for view: CardView in _vm.cards():
		assert_bool(view.face_down).is_false()
		assert_bool(view.taped).is_false()
		assert_bool(view.is_marked()).is_false()
		assert_bool(view.dimmed).is_false()
		assert_int(view.change).is_equal(CardView.Change.NONE)


func test_a_marked_card_shows_its_symbol() -> void:
	_deck.mark(_id_of("AS"), 1)
	assert_int(_view(_id_of("AS")).symbol).is_equal(1)
	assert_bool(_view(_id_of("KS")).is_marked()).is_false()


func test_an_added_card_wears_the_added_look() -> void:
	var added: Card = _deck.add_card(1, Card.Suit.SPADES)
	assert_int(_view(added.id).change).is_equal(CardView.Change.ADDED)
	assert_int(_view(_id_of("AS")).change).is_equal(CardView.Change.NONE)
	assert_str(_row_text(Card.Suit.SPADES)).is_equal("A A 2 3 4 5 6 7 8 9 10 J Q K")


# gdlint: ignore=unused-argument
func test_each_reforge_tier_wears_the_reforged_look(tier: DeckEdit.Kind, test_parameters: Array = [
	[DeckEdit.Kind.REFORGE_RUMMAGE],
	[DeckEdit.Kind.REFORGE_TOUCH_UP],
	[DeckEdit.Kind.REFORGE_FULL],
]) -> void:
	var id: int = _id_of("9H")
	_deck.reforge(id, 10, Card.Suit.HEARTS, tier)
	assert_int(_view(id).change).is_equal(CardView.Change.REFORGED)


func test_a_made_permanent_change_wears_its_sources_look() -> void:
	var sealed: int = _id_of("9H")
	var inked: int = _id_of("2C")
	_deck.make_permanent(sealed, 10, Card.Suit.HEARTS, DeckEdit.Kind.COLD_SEAL)
	_deck.make_permanent(inked, 3, Card.Suit.CLUBS, DeckEdit.Kind.PERMANENT_INK)
	assert_int(_view(sealed).change).is_equal(CardView.Change.SEALED)
	assert_int(_view(inked).change).is_equal(CardView.Change.INKED)


func test_a_card_edited_twice_wears_its_latest_look() -> void:
	var added: Card = _deck.add_card(5, Card.Suit.CLUBS)
	_deck.make_permanent(added.id, 6, Card.Suit.CLUBS, DeckEdit.Kind.COLD_SEAL)
	assert_int(_view(added.id).change).is_equal(CardView.Change.SEALED)
	_deck.reforge(added.id, 7, Card.Suit.CLUBS, DeckEdit.Kind.REFORGE_TOUCH_UP)
	assert_int(_view(added.id).change).is_equal(CardView.Change.REFORGED)


func test_a_reforged_card_sits_where_it_now_reads() -> void:
	_deck.reforge(_id_of("9H"), 2, Card.Suit.SPADES, DeckEdit.Kind.REFORGE_FULL)
	assert_str(_row_text(Card.Suit.HEARTS)).is_equal("A 2 3 4 5 6 7 8 10 J Q K")
	assert_str(_row_text(Card.Suit.SPADES)).is_equal("A 2 2 3 4 5 6 7 8 9 10 J Q K")


func test_a_taped_card_reads_as_taped_in_its_new_row() -> void:
	var id: int = _id_of("9H")
	_tape(id, 9, Card.Suit.SPADES)
	var view: CardView = _view(id)
	assert_bool(view.taped).is_true()
	assert_str(view.rank_text()).is_equal("9")
	assert_int(view.suit).is_equal(Card.Suit.SPADES)
	assert_int(_vm.row(Card.Suit.HEARTS).size()).is_equal(12)
	assert_int(_vm.row(Card.Suit.SPADES).size()).is_equal(14)


func test_a_change_for_this_hand_only_does_not_show() -> void:
	var id: int = _id_of("9H")
	_layer.change(id, 10, Card.Suit.HEARTS)
	assert_str(_view(id).rank_text()).is_equal("9")
	assert_bool(_view(id).taped).is_false()


func test_a_hand_change_over_tape_still_shows_the_taped_card() -> void:
	var id: int = _id_of("9H")
	_tape(id, 10, Card.Suit.HEARTS)
	_layer.change(id, 11, Card.Suit.HEARTS)
	assert_str(_view(id).rank_text()).is_equal("10")
	assert_bool(_view(id).taped).is_true()


func test_tape_covers_a_permanent_changes_look() -> void:
	var id: int = _id_of("9H")
	_deck.make_permanent(id, 10, Card.Suit.HEARTS, DeckEdit.Kind.COLD_SEAL)
	_tape(id, 11, Card.Suit.HEARTS)
	assert_bool(_view(id).taped).is_true()
	assert_int(_view(id).change).is_equal(CardView.Change.NONE)
	_layer.end_session()
	assert_bool(_view(id).taped).is_false()
	assert_int(_view(id).change).is_equal(CardView.Change.SEALED)


## A card's back gives away nothing but its mark, or a change would be a
## free mark (spec §2.3).
func test_a_face_down_card_never_carries_a_change() -> void:
	var view: CardView = CardView.new(_deck.card(0), true, false)
	view.change = CardView.Change.SEALED
	assert_int(view.change).is_equal(CardView.Change.NONE)


func test_the_legend_counts_each_owned_symbol() -> void:
	_kit.add_item(ItemKind.Kind.WAX_PENCIL, ItemRules.from_config(TuneConfig.load_default()))
	_deck.mark(_id_of("AS"), 0)
	_deck.mark(_id_of("AH"), 0)
	_deck.mark(_id_of("KS"), 2)
	var legend: Array[LegendRow] = _vm.legend()
	assert_int(legend.size()).is_equal(3)
	var seen: Array[String] = []
	for row: LegendRow in legend:
		seen.append("%s %d" % [row.name, row.count])
		assert_bool(row.chosen).is_false()
	assert_array(seen).contains_exactly(["Star 2", "Moon 0", "Bolt 1"])


## A symbol item lost to a sweep leaves its marks on the cards (spec §7.6).
func test_the_legend_keeps_a_symbol_the_player_no_longer_owns() -> void:
	_deck.mark(_id_of("KS"), 2)
	var legend: Array[LegendRow] = _vm.legend()
	assert_int(legend.size()).is_equal(3)
	assert_str(legend[2].name).is_equal("Bolt")
	assert_int(legend[2].count).is_equal(1)


func test_choosing_a_symbol_dims_every_card_without_it() -> void:
	_deck.mark(_id_of("AS"), 0)
	_deck.mark(_id_of("KS"), 1)
	_vm.toggle_filter(0)
	assert_bool(_vm.legend()[0].chosen).is_true()
	assert_bool(_vm.legend()[1].chosen).is_false()
	assert_bool(_view(_id_of("AS")).dimmed).is_false()
	assert_bool(_view(_id_of("KS")).dimmed).is_true()
	assert_bool(_view(_id_of("2C")).dimmed).is_true()
	_vm.toggle_filter(1)
	assert_bool(_view(_id_of("AS")).dimmed).is_true()
	assert_bool(_view(_id_of("KS")).dimmed).is_false()
	_vm.toggle_filter(1)
	assert_bool(_view(_id_of("AS")).dimmed).is_false()
	assert_bool(_view(_id_of("2C")).dimmed).is_false()
