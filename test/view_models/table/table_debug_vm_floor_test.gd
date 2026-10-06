extends GdUnitTestSuite
## The debug table sits down at the deck's heat floor (spec §4.2). The
## floor is fixed at sit-down: a mark made during a session counts from the
## next one.

var _deck: Deck
var _vm: TableDebugVM


func before_test() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	_deck = Deck.standard(DeckRules.from_config(config).min_size)
	_vm = TableDebugVM.new(config, _deck, GameRng.new(7))


func _floor() -> float:
	return _vm.session().table_heat.heat_floor


func test_an_unedited_deck_sits_down_at_zero() -> void:
	_vm.sit_down()
	assert_float(_floor()).is_equal(0.0)
	assert_float(_vm.session().table_heat.heat).is_equal(0.0)


func test_an_edited_deck_sits_down_at_its_floor() -> void:
	_deck.remove_card(0)
	_deck.mark(1, 0)
	_vm.sit_down()
	assert_float(_floor()).is_equal_approx(4.0, 0.0001)
	assert_float(_vm.session().table_heat.heat).is_equal_approx(4.0, 0.0001)


func test_a_mark_made_mid_session_counts_from_the_next_session() -> void:
	_vm.sit_down()
	_deck.mark(1, 0)
	assert_float(_floor()).is_equal(0.0)
	_vm.stand_up()
	_vm.sit_down()
	assert_float(_floor()).is_equal_approx(1.0, 0.0001)
