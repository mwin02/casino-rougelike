extends GdUnitTestSuite
## A house rule's name and one-line description for a table offer (spec
## §5.2), and the debug table's rule picker and status line.

var _config: TuneConfig = TuneConfig.load_default()


func _rule_labels(setup: TableSetupVM) -> Array[String]:
	return StackedTableDebugVM.labels(setup.house_rule_choices())


func test_every_rule_in_the_file_has_a_name_and_a_description() -> void:
	for rule: String in _config.house_rules():
		assert_bool(HouseRuleText.NAMES.has(rule)).is_true()
		assert_str(HouseRuleText.name_of(rule)).is_not_empty()
		assert_str(HouseRuleText.describe(rule)).is_not_empty()


# gdlint: ignore=unused-argument
func test_each_rules_text(rule: String, name: String, about: String, test_parameters: Array = [
	["bust_23", "Bust at 23", "23 or more busts, so a 22 is live. The dealer's rules don't change."],
	[
		"nine_only", "Nine only",
		"Only a two-card 9 is a natural. A two-card 8 no longer ends the hand.",
	],
	["aces_high", "Aces high", "The ace ranks above the king."],
	["no_side_bets", "No side bets", "This table takes no side bets."],
]) -> void:
	assert_str(HouseRuleText.name_of(rule)).is_equal(name)
	assert_str(HouseRuleText.describe(rule)).is_equal(about)


func test_no_rule_reads_as_nothing() -> void:
	assert_str(HouseRuleText.name_of("")).is_empty()
	assert_str(HouseRuleText.offer_line("")).is_empty()


func test_an_unnamed_rule_falls_back_to_its_config_name() -> void:
	assert_str(HouseRuleText.name_of("tens_wild")).is_equal("Tens wild")
	assert_str(HouseRuleText.offer_line("tens_wild")).is_equal("House rule: Tens wild")


func test_the_offer_line_gives_the_name_and_what_it_does() -> void:
	assert_str(HouseRuleText.offer_line("aces_high")).is_equal(
		"House rule: Aces high. The ace ranks above the king."
	)


func test_the_picker_offers_none_and_the_rules_that_fit_the_game() -> void:
	var setup: TableSetupVM = TableSetupVM.new(_config)
	assert_array(_rule_labels(setup)).contains_exactly(
		["No house rule", "Bust at 23", "No side bets"]
	)
	setup.choose_game(GameKind.Kind.BACCARAT)
	assert_array(_rule_labels(setup)).contains_exactly(
		["No house rule", "Nine only", "No side bets"]
	)
	setup.choose_game(GameKind.Kind.HIGH_LOW)
	assert_array(_rule_labels(setup)).contains_exactly(
		["No house rule", "Aces high", "No side bets"]
	)


func test_the_chosen_rule_goes_on_the_table() -> void:
	var setup: TableSetupVM = TableSetupVM.new(_config)
	assert_str(setup.table().house_rule).is_empty()
	assert_bool(setup.house_rule_choices()[0].selected).is_true()
	var choice: Choice = StackedTableDebugVM.find(setup.house_rule_choices(), "Bust at 23")
	setup.choose_house_rule(choice.id)
	assert_str(setup.table().house_rule).is_equal("bust_23")
	choice = StackedTableDebugVM.find(setup.house_rule_choices(), "Bust at 23")
	assert_bool(choice.selected).is_true()
	setup.choose_house_rule(99)
	assert_str(setup.table().house_rule).is_empty()
	setup.choose_house_rule(choice.id)
	setup.choose_house_rule(0)
	assert_str(setup.table().house_rule).is_empty()


func test_changing_game_drops_a_rule_that_no_longer_fits() -> void:
	var setup: TableSetupVM = TableSetupVM.new(_config)
	var choice: Choice = StackedTableDebugVM.find(setup.house_rule_choices(), "Bust at 23")
	setup.choose_house_rule(choice.id)
	setup.choose_game(GameKind.Kind.BACCARAT)
	assert_str(setup.table().house_rule).is_empty()
	assert_bool(setup.house_rule_choices()[0].selected).is_true()


func test_changing_game_keeps_a_rule_for_any_game() -> void:
	var setup: TableSetupVM = TableSetupVM.new(_config)
	var choice: Choice = StackedTableDebugVM.find(setup.house_rule_choices(), "No side bets")
	setup.choose_house_rule(choice.id)
	setup.choose_game(GameKind.Kind.BACCARAT)
	assert_str(setup.table().house_rule).is_equal("no_side_bets")


func test_a_seated_table_shows_its_rule_in_the_status() -> void:
	var vm: StackedTableDebugVM = StackedTableDebugVM.on(["10", "10", "5", "8", "7"])
	var choice: Choice = StackedTableDebugVM.find(vm.setup.house_rule_choices(), "Bust at 23")
	vm.setup.choose_house_rule(choice.id)
	vm.sit_down()
	assert_array(vm.status_lines()).contains([HouseRuleText.offer_line("bust_23")])
	assert_str(HouseRuleText.offer_line("bust_23")).starts_with("House rule: Bust at 23. 23 or")


func test_a_table_with_no_rule_shows_no_rule_line() -> void:
	var vm: StackedTableDebugVM = StackedTableDebugVM.on(["10", "10", "5", "8", "7"])
	vm.sit_down()
	for line: String in vm.status_lines():
		assert_bool(line.begins_with("House rule")).is_false()


func test_a_no_side_bets_table_shows_no_side_bet_buttons() -> void:
	var vm: StackedTableDebugVM = StackedTableDebugVM.on(["7H", "5S", "7D", "9C", "K"])
	var choice: Choice = StackedTableDebugVM.find(vm.setup.house_rule_choices(), "No side bets")
	vm.setup.choose_house_rule(choice.id)
	vm.sit_down()
	assert_array(vm.side_bets.choices()).is_empty()
	assert_array(vm.side_bets.bets()).is_empty()
