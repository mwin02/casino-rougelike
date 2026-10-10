extends GdUnitTestSuite
## Choosing the debug table: game, stakes, floor (spec §6.3 stakes) and kit.

var _setup: TableSetupVM


func before_test() -> void:
	_setup = TableSetupVM.new(TuneConfig.load_default())


func _selected(choices: Array[Choice]) -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in choices:
		if choice.selected:
			labels.append(choice.label)
	return labels


func test_defaults_are_blackjack_low_stakes_floor_1_every_action() -> void:
	assert_array(_selected(_setup.game_choices())).contains_exactly(["Blackjack"])
	assert_array(_selected(_setup.stakes_choices())).contains_exactly(["Low stakes"])
	assert_array(_selected(_setup.floor_choices())).contains_exactly(["Floor 1"])
	assert_array(_selected(_setup.kit_choices())).contains_exactly(["Every action"])


func test_the_table_follows_game_stakes_and_floor() -> void:
	_setup.choose_game(GameKind.Kind.HIGH_LOW)
	_setup.choose_stakes(TableStakes.Kind.HIGH)
	_setup.choose_floor(2)
	var table: Table = _setup.table()
	assert_int(table.game).is_equal(GameKind.Kind.HIGH_LOW)
	assert_int(table.table_min).is_equal(20000)
	assert_int(table.table_max).is_equal(80000)
	assert_array(_selected(_setup.floor_choices())).contains_exactly(["Floor 2"])


func test_floor_stays_between_1_and_5() -> void:
	_setup.choose_floor(9)
	assert_int(_setup.floor_number).is_equal(5)


func test_every_action_kit_carries_consumables() -> void:
	assert_bool(_setup.kit.has(ActionKind.Kind.PALM)).is_true()
	assert_int(_setup.kit.masking_tape).is_equal(TableSetupVM.DEBUG_TAPE)
	assert_int(_setup.kit.cold_seals).is_equal(TableSetupVM.DEBUG_SEALS)
	var ink: int = TuneConfig.load_default().get_int("items", "ink_charges_per_floor")
	assert_int(_setup.kit.ink_charges).is_equal(ink)
	assert_bool(_setup.kit.has_item(ItemKind.Kind.LOADED_QUESTION)).is_true()


func test_starting_kit_has_only_the_starting_actions() -> void:
	_setup.choose_kit(TableSetupVM.KitChoice.STARTING)
	assert_bool(_setup.kit.has(ActionKind.Kind.NUDGE)).is_true()
	assert_bool(_setup.kit.has(ActionKind.Kind.FULL_REVEAL)).is_false()
	assert_int(_setup.kit.masking_tape).is_equal(0)
	assert_int(_setup.kit.questions_per_reveal).is_equal(1)
