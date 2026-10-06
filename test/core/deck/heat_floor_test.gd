extends GdUnitTestSuite
## The deviation heat floor (spec §4.2): a step per deck edit and per marked
## card, Luminous Ink marks at half, and Forged Papers' cut. Each edit kind
## gets its own step here so a test can tell them apart.

const MIN_SIZE: int = 20

var _deck: Deck
var _kit: ActionKit
var _rules: DeckRules


func before_test() -> void:
	_deck = Deck.standard(MIN_SIZE)
	_kit = ActionKit.starting()
	_rules = DeckRules.from_config(TuneConfig.load_default())
	_rules.floor_per_removal = 3.0
	_rules.floor_per_addition = 4.0
	_rules.floor_per_rummage = 5.0
	_rules.floor_per_touch_up = 6.0
	_rules.floor_per_full_reforge = 7.0
	_rules.floor_per_cold_seal = 1.0
	_rules.floor_per_ink = 2.0
	_rules.floor_per_mark = 1.0
	_rules.floor_per_luminous_mark = 0.5
	_rules.forged_papers_floor_cut = 10.0


func _floor() -> float:
	return HeatFloor.of(_deck, _kit, _rules)


func test_a_standard_deck_has_no_floor() -> void:
	assert_float(_floor()).is_equal(0.0)


func test_each_removal_and_addition_steps_the_floor() -> void:
	_deck.remove_card(0)
	assert_float(_floor()).is_equal_approx(3.0, 0.0001)
	_deck.add_card(1, Card.Suit.SPADES)
	assert_float(_floor()).is_equal_approx(7.0, 0.0001)


func test_each_reforge_tier_has_its_own_step() -> void:
	_deck.reforge(0, 2, Card.Suit.CLUBS, DeckEdit.Kind.REFORGE_RUMMAGE)
	assert_float(_floor()).is_equal_approx(5.0, 0.0001)
	_deck.reforge(1, 3, Card.Suit.CLUBS, DeckEdit.Kind.REFORGE_TOUCH_UP)
	assert_float(_floor()).is_equal_approx(11.0, 0.0001)
	_deck.reforge(2, 13, Card.Suit.CLUBS, DeckEdit.Kind.REFORGE_FULL)
	assert_float(_floor()).is_equal_approx(18.0, 0.0001)


func test_cold_seal_and_permanent_ink_have_their_own_steps() -> void:
	_deck.make_permanent(0, 2, Card.Suit.CLUBS, DeckEdit.Kind.COLD_SEAL)
	assert_float(_floor()).is_equal_approx(1.0, 0.0001)
	_deck.make_permanent(1, 3, Card.Suit.CLUBS, DeckEdit.Kind.PERMANENT_INK)
	assert_float(_floor()).is_equal_approx(3.0, 0.0001)


func test_removing_a_card_and_adding_it_back_is_two_edits() -> void:
	var removed: Card = _deck.card(0)
	_deck.remove_card(removed.id)
	_deck.add_card(removed.rank, removed.suit)
	assert_dict(_deck.composition()).is_equal(Deck.standard(MIN_SIZE).composition())
	assert_float(_floor()).is_equal_approx(7.0, 0.0001)


func test_each_marked_card_steps_the_floor() -> void:
	_deck.mark(0, 0)
	_deck.mark(1, 1)
	assert_float(_floor()).is_equal_approx(2.0, 0.0001)


func test_re_marking_a_card_does_not_add_a_step() -> void:
	_deck.mark(0, 0)
	_deck.mark(0, 1)
	assert_float(_floor()).is_equal_approx(1.0, 0.0001)


func test_clearing_a_mark_lowers_the_floor() -> void:
	_deck.mark(0, 0)
	_deck.mark(1, 0)
	_deck.clear_mark(0)
	assert_float(_floor()).is_equal_approx(1.0, 0.0001)


func test_luminous_marks_step_by_their_own_amount() -> void:
	_kit.luminous_symbols = [2]
	_deck.mark(0, 2)
	_deck.mark(1, 0)
	assert_float(_floor()).is_equal_approx(1.5, 0.0001)


func test_forged_papers_cuts_the_floor() -> void:
	_kit.forged_papers = true
	for id: int in 4:
		_deck.remove_card(id)
	assert_float(_floor()).is_equal_approx(2.0, 0.0001)


func test_forged_papers_never_takes_the_floor_below_zero() -> void:
	_kit.forged_papers = true
	_deck.mark(0, 0)
	assert_float(_floor()).is_equal(0.0)
