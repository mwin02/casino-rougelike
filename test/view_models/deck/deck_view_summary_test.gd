extends GdUnitTestSuite
## The deck screen's summary (spec §4.4): the card count, the sizes, the
## marks' caption, the heat floor the deck gives the next table (§4.2) and
## the house deck note (§7.2), and what the table flow opens it with.

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


func test_the_count_follows_removals_and_additions() -> void:
	assert_str(_vm.count_text()).is_equal("52 cards")
	_deck.remove_card(_id_of("2C"))
	_deck.remove_card(_id_of("3C"))
	assert_str(_vm.count_text()).is_equal("50 cards")
	_deck.add_card(1, Card.Suit.SPADES)
	assert_str(_vm.count_text()).is_equal("51 cards")
	assert_int(_vm.cards().size()).is_equal(51)


func test_the_size_note_gives_the_standard_and_minimum_sizes() -> void:
	assert_str(_vm.size_note()).is_equal("STANDARD 52 · MIN %d" % MIN_SIZE)


func test_the_marks_caption_counts_marked_cards() -> void:
	assert_str(_vm.marks_caption()).is_equal("YOUR MARKS · 0 CARDS")
	_deck.mark(_id_of("AS"), 0)
	assert_str(_vm.marks_caption()).is_equal("YOUR MARKS · 1 CARD")
	_deck.mark(_id_of("KS"), 1)
	assert_str(_vm.marks_caption()).is_equal("YOUR MARKS · 2 CARDS")


## Whole, rounded down, as the heat meter shows heat (spec §1.4).
func test_the_heat_floor_shows_as_a_whole_number() -> void:
	assert_str(_vm.heat_floor_text()).is_equal("0")
	var raised: DeckViewVM = DeckViewVM.new(_deck, _layer, _kit, 23.5)
	assert_str(raised.heat_floor_text()).is_equal("23")


## The floor the next table would start at (spec §4.2): the deck as it is
## now, not as it was when this table was sat down at.
func test_the_table_flow_gives_the_decks_heat_floor_as_it_is_now() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var flow: TableFlowVM = TableFlowVM.new(config, _deck, GameRng.new(1))
	flow.setup.kit = ActionKit.starting()
	assert_str(flow.deck_view().heat_floor_text()).is_equal("0")
	_deck.remove_card(_id_of("2C"))
	_deck.mark(_id_of("AS"), 0)
	var rules: DeckRules = DeckRules.from_config(config)
	var expected: float = rules.floor_per_edit(DeckEdit.Kind.REMOVE) + rules.floor_per_mark
	assert_str(flow.deck_view().heat_floor_text()).is_equal(str(floori(expected)))


func test_the_house_deck_note_shows_only_after_a_swap() -> void:
	assert_str(_vm.house_deck_note()).is_equal("")
	var swapped: DeckViewVM = DeckViewVM.new(_deck, _layer, _kit, 0.0, true)
	assert_str(swapped.house_deck_note()).is_equal(DeckViewVM.HOUSE_DECK_NOTE)
	assert_int(swapped.cards().size()).is_equal(52)


func test_the_table_flow_opens_the_deck_it_plays_with() -> void:
	_deck.mark(_id_of("AS"), 1)
	var flow: TableFlowVM = TableFlowVM.new(TuneConfig.load_default(), _deck, GameRng.new(1))
	var view: DeckViewVM = flow.deck_view()
	assert_str(view.count_text()).is_equal("52 cards")
	assert_int(view.legend()[1].count).is_equal(1)
	assert_str(view.house_deck_note()).is_equal("")


## Setup's kit can change between tables; the table plays with the one it
## sat down with.
func test_at_a_table_the_deck_shows_the_kit_it_sat_down_with() -> void:
	var flow: StackedTableDebugVM = StackedTableDebugVM.on(["9S", "2H", "KD", "3C"])
	flow.setup.choose_game(GameKind.Kind.BACCARAT)
	flow.setup.kit = ActionKit.starting()
	flow.sit_down()
	flow.setup.kit = ActionKit.everything()
	var view: DeckViewVM = flow.deck_view()
	assert_int(view.legend().size()).is_equal(ActionKit.STARTING_SYMBOLS.size())
	assert_str(view.house_deck_note()).is_equal("")
	assert_str(view.count_text()).is_equal("4 cards")
