extends GdUnitTestSuite
## A node's table offers (block U4, spec §5.2): game, stakes, house rule and
## the pit boss's eye; sitting needs the table's minimum; Back to map leaves
## the node. The run is at the first node of a seeded floor 1.

const PATH: String = "user://test_offers_vm.bin"

var _config: TuneConfig = TuneConfig.load_default()
var _owner: RunVM
var _node: MapNode
var _vm: OffersVM


func before_test() -> void:
	SaveStore.clear(PATH)
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = 21
	_owner = RunVM.new(_config, seeds, PATH)
	_owner.start()
	var floor: Floor = _owner.run.floor
	_node = floor.choices()[0]
	floor.enter(_node)
	_owner.step_done()
	_vm = OffersVM.new(_owner)


func after_test() -> void:
	SaveStore.clear(PATH)


## Where the Marked tier starts (spec §7.1).
func _marked() -> int:
	return roundi(_config.get_float_list("tiers", "thresholds")[1])


func test_the_header_names_the_node_and_its_row() -> void:
	assert_str(_vm.title()).is_equal(TableSetupVM.STAKES_NAMES[_node.stakes])
	assert_bool(_vm.is_high_stakes()).is_equal(_node.is_high_stakes())
	assert_str(_vm.row_text()).is_equal(
		"ROW 1 OF %d · PICK A TABLE" % _config.get_int("map", "rows")
	)
	assert_str(_vm.hud().floor_title()).is_equal("FLOOR 1 · BASELINE")


func test_every_table_at_the_node_is_offered() -> void:
	var offers: Array[TableOffer] = _vm.offers()
	assert_int(offers.size()).is_equal(_node.tables.size())
	for i: int in offers.size():
		var table: Table = _node.tables[i]
		assert_int(offers[i].index).is_equal(i)
		assert_int(offers[i].game).is_equal(table.game)
		assert_str(offers[i].name).is_equal(TableSetupVM.GAME_NAMES[table.game])
		assert_str(offers[i].stakes_text).is_equal(
			"%s–%s" % [MoneyFormat.format(table.table_min), MoneyFormat.format(table.table_max)]
		)
		assert_str(offers[i].rule_text).is_equal("None")


func test_an_offer_shows_its_house_rule() -> void:
	var table: Table = _node.tables[0]
	var rule: String = _config.house_rules_for(GameKind.config_section(table.game))[0]
	table.house_rule = rule
	var offer: TableOffer = _vm.offers()[0]
	assert_str(offer.rule_text).is_equal(HouseRuleText.name_of(rule))
	assert_str(offer.rule_note).is_equal(HouseRuleText.describe(rule))


func test_cost_rolls_stay_hidden_and_the_marked_line_is_known() -> void:
	var offer: TableOffer = _vm.offers()[0]
	assert_str(_vm.tier_text(offer)).is_equal("Clean")
	assert_str(_vm.hidden_note(offer)).is_equal("Something bad happens at %d." % _marked())


func test_a_watched_table_says_so() -> void:
	_node.tables[0].watched = true
	var offer: TableOffer = _vm.offers()[0]
	assert_bool(offer.watched).is_true()
	assert_str(_vm.tier_text(offer)).is_equal("Watched")
	assert_str(_vm.hidden_note(offer)).is_equal(
		"Watched from the first hand. Something bad happens at %d." % _marked()
	)


func test_sitting_needs_the_tables_minimum() -> void:
	var offer: TableOffer = _vm.offers()[0]
	var table_min: int = _node.tables[0].table_min
	assert_bool(_vm.can_sit(offer)).is_true()
	assert_str(_vm.sit_label(offer)).is_equal("Sit")
	_owner.run.state.bankroll = table_min - 1
	assert_bool(_vm.can_sit(offer)).is_false()
	assert_str(_vm.sit_label(offer)).is_equal("Needs " + MoneyFormat.format(table_min))
	_vm.sit(offer)
	assert_int(_owner.screen()).is_equal(RunVM.Screen.OFFERS)


func test_sitting_opens_that_table_and_saves() -> void:
	var offers: Array[TableOffer] = _vm.offers()
	var last: TableOffer = offers[offers.size() - 1]
	_vm.sit(last)
	assert_int(_owner.screen()).is_equal(RunVM.Screen.TABLE)
	assert_object(_owner.run.floor.session.table).is_same(_node.tables[last.index])
	assert_object(SaveStore.load_from(_config, PATH).floor.session).is_not_null()


func test_skip_leaves_the_node_without_a_hand_played() -> void:
	var hands: int = _owner.run.floor.clock.hands_left
	_vm.skip()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_owner.run.floor.clock.hands_left).is_equal(hands)
	assert_bool(_node in _owner.run.floor.choices()).is_false()
	assert_int(_owner.run.floor.phase).is_equal(Floor.Phase.MAP)


func test_back_to_map_shows_the_map_and_decides_nothing() -> void:
	_vm.back()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)
	assert_int(_owner.run.floor.phase).is_equal(Floor.Phase.AT_TABLE)
	assert_object(_owner.run.floor.session).is_null()


func test_the_map_leads_back_to_the_tables() -> void:
	_vm.back()
	var map: MapVM = MapVM.new(_owner)
	assert_int(map.selected().row).is_equal(_node.row)
	assert_int(map.selected().lane).is_equal(_node.lane)
	assert_int(map.selected().status).is_equal(MapNodeView.Status.CURRENT)
	assert_str(map.walk_label()).is_equal("Back to tables")
	assert_bool(map.can_walk()).is_true()
	map.walk()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.OFFERS)
	OffersVM.new(_owner).sit(OffersVM.new(_owner).offers()[0])
	assert_int(_owner.screen()).is_equal(RunVM.Screen.TABLE)


func test_no_other_node_can_be_walked_to_while_the_tables_wait() -> void:
	_vm.back()
	var map: MapVM = MapVM.new(_owner)
	var next: MapNode = _owner.run.floor.map.next_of(_node)[0]
	map.select(next.row, next.lane)
	assert_bool(map.can_walk()).is_false()
	assert_str(map.walk_label()).is_equal("Not linked yet")
	assert_bool(map.can_cash_out()).is_false()
	assert_str(map.cash_out_note()).is_equal("Sit or skip the tables first")


func test_a_run_continued_from_the_map_view_is_back_at_the_tables() -> void:
	_vm.back()
	MapVM.new(_owner).go_home()
	_owner.continue_run()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.OFFERS)
