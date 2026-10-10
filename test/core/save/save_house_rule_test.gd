extends GdUnitTestSuite
## A table's house rule saves with the run (spec §5.2; save version 8): a
## seated session resumes under it, and a save naming a rule the config
## doesn't hold is refused.

const PATH: String = "user://test_save_house_rule.bin"
const SEED: int = 4242
const RULE: String = "bust_23"

var _config: TuneConfig = TuneConfig.load_default()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## A run on floor 1 whose first node's first table is blackjack under RULE.
func _run() -> Run:
	var run: Run = Run.start(_config, SEED)
	var table: Table = run.floor.map.row(0)[0].tables[0]
	table.game = GameKind.Kind.BLACKJACK
	table.house_rule = RULE
	return run


func test_a_tables_rule_survives_save_and_resume() -> void:
	var run: Run = _run()
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	var resumed: Run = SaveStore.load_from(_config, PATH)
	assert_object(resumed).is_not_null()
	assert_str(resumed.floor.map.row(0)[0].tables[0].house_rule).is_equal(RULE)
	assert_dict(resumed.to_dict()).is_equal(run.to_dict())


func test_a_seated_session_resumes_under_its_tables_rule() -> void:
	var run: Run = _run()
	run.floor.enter(run.floor.map.row(0)[0])
	run.floor.sit(0)
	assert_int(SaveStore.save(run, PATH)).is_equal(OK)
	var resumed: Run = SaveStore.load_from(_config, PATH)
	var session: TableSession = resumed.floor.session
	assert_object(session).is_not_null()
	session.start_hand(session.table.table_min)
	# §3.1: a 22 is live at a bust-23 table.
	var hand: BlackjackHand = (session.current_round() as BlackjackRound).active_hand()
	hand.cards.clear()
	for code: String in ["10", "5", "7"]:
		hand.add(Card.parse(code))
	assert_int(hand.total()).is_equal(22)
	assert_bool(hand.is_bust()).is_false()


func test_a_save_naming_an_unknown_rule_is_refused() -> void:
	var saved: Dictionary = _run().to_dict()
	var floor: Dictionary = saved["floor"]
	var map: Dictionary = floor["map"]
	var nodes: Array = map["nodes"]
	var node: Dictionary = nodes[0]
	var tables: Array = node["tables"]
	var table: Dictionary = tables[0]
	table["house_rule"] = "no_such_rule"
	assert_object(SaveStore.from_saved(saved, _config)).is_null()


func test_a_save_from_before_house_rules_is_refused() -> void:
	# Save version 7 had no house_rule on its tables.
	var saved: Dictionary = _run().to_dict()
	saved["version"] = 7
	assert_object(SaveStore.from_saved(saved, _config)).is_null()
