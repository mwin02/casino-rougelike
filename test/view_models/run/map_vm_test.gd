extends GdUnitTestSuite
## The floor map (block U4, spec §5.2, §6.5) on a hand-made map of three
## rows: low tables at (0,0) and (0,2); a shop (1,0), high tables (1,1) and
## deck services (1,2); high tables (2,0) and low tables (2,2). (0,0) links
## to the shop and the high tables, (0,2) to deck services; the shop and
## (1,1) link to (2,0), deck services to (2,2).

const PATH: String = "user://test_map_vm.bin"

var _config: TuneConfig = TuneConfig.load_default()
var _owner: RunVM
var _floor: Floor


func before_test() -> void:
	SaveStore.clear(PATH)
	var seeds: RandomNumberGenerator = RandomNumberGenerator.new()
	seeds.seed = 3
	_owner = RunVM.new(_config, seeds, PATH)
	_owner.start()
	var run: Run = _owner.run
	var f: FloorFixture = FloorFixture.new()
	var nodes: Array[MapNode] = [
		f.tables(0, 0, [0, 1]),
		f.tables(0, 2, [2]),
		f.back_room(1, 0, MapNode.Kind.SHOP, [0]),
		f.tables(1, 1, [0], TableStakes.Kind.HIGH),
		f.back_room(1, 2, MapNode.Kind.DECK_SERVICES, [2]),
		f.tables(2, 0, [], TableStakes.Kind.HIGH),
		f.tables(2, 2, []),
	]
	_floor = Floor.new(
		run.config(), run.state, run.game.deck, run.game.layer, run.kit, run.game.rng,
		FloorMap.from_nodes(3, nodes)
	)
	run.floor = _floor


func after_test() -> void:
	SaveStore.clear(PATH)


## Enters the node and leaves it without sitting.
func _pass_through(row: int, lane: int) -> void:
	_floor.enter(_floor.map.node_at(row, lane))
	_floor.leave()


func _status(row: int, lane: int) -> MapNodeView.Status:
	for view: MapNodeView in MapVM.new(_owner).nodes():
		if view.row == row and view.lane == lane:
			return view.status
	fail("no node at %d, %d" % [row, lane])
	return MapNodeView.Status.PAST


func test_every_node_is_on_the_map_with_its_tag() -> void:
	var tags: Array[String] = []
	for view: MapNodeView in MapVM.new(_owner).nodes():
		tags.append(view.tag)
	assert_array(tags).contains_exactly([
		"LOW · 1", "LOW · 1", "SHOP", "HIGH · 1", "DECK", "HIGH · 1", "LOW · 1",
	])
	assert_int(MapVM.new(_owner).row_count()).is_equal(3)
	assert_int(MapVM.new(_owner).lane_count()).is_equal(_config.get_int("map", "lanes"))


func test_a_node_keeps_its_links_to_the_next_row() -> void:
	var first: MapNodeView = MapVM.new(_owner).nodes()[0]
	assert_array(first.next_lanes).contains_exactly([0, 1])
	assert_int(first.look).is_equal(MapNodeView.Look.LOW)


func test_before_the_first_step_the_first_row_is_one_step_away() -> void:
	assert_int(_status(0, 0)).is_equal(MapNodeView.Status.REACHABLE)
	assert_int(_status(0, 2)).is_equal(MapNodeView.Status.REACHABLE)
	assert_int(_status(1, 1)).is_equal(MapNodeView.Status.AHEAD)
	assert_int(_status(2, 2)).is_equal(MapNodeView.Status.AHEAD)
	assert_int(MapVM.new(_owner).focus_row()).is_equal(0)


func test_a_step_marks_where_you_are_and_what_fell_off_the_route() -> void:
	_pass_through(0, 0)
	assert_int(_status(0, 0)).is_equal(MapNodeView.Status.CURRENT)
	assert_int(_status(0, 2)).is_equal(MapNodeView.Status.PAST)
	assert_int(_status(1, 0)).is_equal(MapNodeView.Status.REACHABLE)
	assert_int(_status(1, 1)).is_equal(MapNodeView.Status.REACHABLE)
	assert_int(_status(1, 2)).is_equal(MapNodeView.Status.PAST)
	assert_int(_status(2, 0)).is_equal(MapNodeView.Status.AHEAD)
	assert_int(_status(2, 2)).is_equal(MapNodeView.Status.PAST)
	assert_int(MapVM.new(_owner).focus_row()).is_equal(1)


func test_nodes_walked_earlier_stay_marked() -> void:
	_pass_through(0, 0)
	_pass_through(1, 1)
	assert_int(_status(0, 0)).is_equal(MapNodeView.Status.VISITED)
	assert_int(_status(1, 1)).is_equal(MapNodeView.Status.CURRENT)
	assert_int(_status(1, 0)).is_equal(MapNodeView.Status.PAST)


func test_the_first_node_one_step_away_is_picked_to_start() -> void:
	_pass_through(0, 0)
	var map: MapVM = MapVM.new(_owner)
	assert_int(map.selected().row).is_equal(1)
	assert_int(map.selected().lane).is_equal(0)
	assert_str(map.selected_title()).is_equal("Shop")
	assert_str(map.selected_row_text()).is_equal("ROW 2 OF 3")
	assert_str(map.selected_sub()).is_equal("Back room")
	assert_array(map.selected_offers()).is_empty()
	assert_str(map.selected_note()).is_equal(
		"Items and consumables at floor 1 prices. Costs no hands."
	)


func test_picking_a_table_node_shows_its_offers() -> void:
	var map: MapVM = MapVM.new(_owner)
	map.select(1, 1)
	assert_bool(map.selected().selected).is_true()
	assert_str(map.selected_title()).is_equal("High stakes")
	assert_str(map.selected_sub()).is_equal("1 table · bets $5,000–$20,000")
	var offers: Array[TableOffer] = map.selected_offers()
	assert_int(offers.size()).is_equal(1)
	assert_str(offers[0].name).is_equal("High or Low")
	assert_str(offers[0].stakes_text).is_equal("$5,000–$20,000")
	assert_str(offers[0].rule_text).is_equal("None")
	assert_bool(offers[0].watched).is_false()
	assert_str(map.selected_note()).is_equal(MapVM.HIDDEN_ROLLS)
	var picked: Array[MapNodeView] = map.nodes().filter(
		func(view: MapNodeView) -> bool: return view.selected
	)
	assert_int(picked.size()).is_equal(1)


func test_picking_deck_services_says_what_it_is() -> void:
	var map: MapVM = MapVM.new(_owner)
	map.select(1, 2)
	assert_str(map.selected_title()).is_equal("Deck services")
	assert_str(map.selected_note()).is_equal(MapVM.DECK_NOTE)


func test_a_pick_off_the_map_changes_nothing() -> void:
	var map: MapVM = MapVM.new(_owner)
	map.select(9, 9)
	assert_int(map.selected().row).is_equal(0)


func test_a_watched_table_shows_on_its_node_and_its_offer() -> void:
	_floor.map.node_at(1, 1).tables[0].watched = true
	var map: MapVM = MapVM.new(_owner)
	map.select(1, 1)
	assert_bool(map.selected().watched).is_true()
	assert_bool(map.selected_offers()[0].watched).is_true()
	assert_str(map.selected_note()).is_equal(
		"The pit boss watches the High or Low table from the first hand. " + MapVM.HIDDEN_ROLLS
	)
	map.select(0, 0)
	assert_bool(map.selected().watched).is_false()


func test_an_offer_names_its_house_rule() -> void:
	var rule: String = _config.house_rules_for(
		GameKind.config_section(GameKind.Kind.HIGH_LOW)
	)[0]
	_floor.map.node_at(0, 0).tables[0].house_rule = rule
	var map: MapVM = MapVM.new(_owner)
	map.select(0, 0)
	var offer: TableOffer = map.selected_offers()[0]
	assert_str(offer.rule_text).is_equal(HouseRuleText.name_of(rule))
	assert_str(offer.rule_note).is_equal(HouseRuleText.describe(rule))


func test_only_a_node_one_step_away_can_be_walked_to() -> void:
	_pass_through(0, 0)
	var map: MapVM = MapVM.new(_owner)
	var labels: Dictionary[String, bool] = {}
	for at: Vector2i in [Vector2i(1, 0), Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2)]:
		map.select(at.x, at.y)
		labels[map.walk_label()] = map.can_walk()
	assert_dict(labels).is_equal({
		"Walk here": true, "You are here": false, "Not linked yet": false,
		"Off your route": false,
	})
	map.walk()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)
	_pass_through(1, 1)
	map = MapVM.new(_owner)
	map.select(0, 0)
	assert_str(map.walk_label()).is_equal("Already walked")


func test_walking_to_tables_opens_their_offers_and_saves() -> void:
	var map: MapVM = MapVM.new(_owner)
	map.select(0, 2)
	map.walk()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.OFFERS)
	assert_object(_floor.current).is_same(_floor.map.node_at(0, 2))
	assert_int(SaveStore.load_from(_config, PATH).floor.walked.size()).is_equal(1)


func test_walking_to_a_back_room_opens_it() -> void:
	_pass_through(0, 0)
	MapVM.new(_owner).walk()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.SHOP)
	_floor.leave()
	_owner.step_done()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)


func test_cash_out_waits_for_the_quota() -> void:
	var map: MapVM = MapVM.new(_owner)
	assert_bool(map.can_cash_out()).is_false()
	assert_str(map.cash_out_note()).is_equal("Cash out opens at the $140,000 quota")
	map.cash_out()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.MAP)


func test_cash_out_says_what_it_sheds_and_ends_the_walk() -> void:
	_owner.run.state.bankroll = 151_200
	_owner.run.state.run_heat = 46.0
	_floor.clock.hands_left = 27
	var map: MapVM = MapVM.new(_owner)
	assert_bool(map.can_cash_out()).is_true()
	# Spec §6.5: each unused hand sheds 1 run heat.
	assert_str(map.cash_out_text()).is_equal("−27 run heat")
	map.cash_out()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.END_SHOP)
	assert_float(_owner.run.state.run_heat).is_equal_approx(19.0, 0.0001)


func test_cash_out_never_sheds_more_heat_than_there_is() -> void:
	_owner.run.state.bankroll = 151_200
	_owner.run.state.run_heat = 10.0
	_floor.clock.hands_left = 27
	assert_str(MapVM.new(_owner).cash_out_text()).is_equal("−10 run heat")


func test_home_saves_the_run_and_leaves_it() -> void:
	MapVM.new(_owner).go_home()
	assert_int(_owner.screen()).is_equal(RunVM.Screen.HOME)
	assert_bool(_owner.has_save()).is_true()
