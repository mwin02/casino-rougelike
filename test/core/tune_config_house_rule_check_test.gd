extends GdUnitTestSuite
## House rules are checked on load (spec §5.2, §5.3): a rule names a game and
## changes only that game's section and [side_bets], with values of the right
## type. An override that fails a check is never written.


func _default_text() -> String:
	return FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)


## The default file with one more house rule section at the end.
func _with_rule(name: String, lines: String) -> TuneConfig:
	return TuneConfig.parse("%s\n[house_rule_%s]\n\n%s\n" % [_default_text(), name, lines])


func _has_problem(config: TuneConfig, fragment: String) -> bool:
	for problem: String in config.problems():
		if problem.contains(fragment):
			return true
	return false


func test_a_rule_without_a_game_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("lost", "blackjack.bust_threshold=24")
	assert_bool(_has_problem(config, "house_rule_lost/game")).is_true()


func test_a_rule_for_an_unknown_game_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("lost", 'game="roulette"')
	assert_bool(_has_problem(config, "house_rule_lost/game")).is_true()


func test_a_rule_changing_another_games_section_is_a_problem() -> void:
	var config: TuneConfig = _with_rule(
		"cross", 'game="blackjack"\nbaccarat.banker_commission_pct=0'
	)
	assert_bool(_has_problem(config, "house_rule_cross/baccarat.banker_commission_pct")).is_true()


func test_a_rule_for_any_game_changes_only_side_bets() -> void:
	var config: TuneConfig = _with_rule("cross", 'game="any"\nblackjack.bust_threshold=24')
	assert_bool(_has_problem(config, "house_rule_cross/blackjack.bust_threshold")).is_true()


func test_a_rule_changing_a_shared_section_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("cross", 'game="blackjack"\nheat.max_raise_pct=100')
	assert_bool(_has_problem(config, "house_rule_cross/heat.max_raise_pct")).is_true()


func test_a_rule_naming_an_unknown_key_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("typo", 'game="blackjack"\nblackjack.bust_treshold=23')
	assert_bool(_has_problem(config, "house_rule_typo/blackjack.bust_treshold")).is_true()


func test_a_rule_value_of_the_wrong_type_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("typed", 'game="blackjack"\nblackjack.bust_threshold=23.5')
	assert_bool(_has_problem(config, "house_rule_typed/blackjack.bust_threshold")).is_true()


func test_a_rule_list_of_the_wrong_length_is_a_problem() -> void:
	var config: TuneConfig = _with_rule("short", 'game="blackjack"\nside_bets.bust_it=[1, 2]')
	assert_bool(_has_problem(config, "house_rule_short/side_bets.bust_it")).is_true()


func test_a_refused_override_is_never_written() -> void:
	var config: TuneConfig = _with_rule(
		"cross", 'game="blackjack"\nbaccarat.banker_commission_pct=0\nblackjack.bust_threshold=24'
	)
	var at: TuneConfig = config.for_house_rule("cross")
	assert_int(at.get_int("baccarat", "banker_commission_pct")).is_equal(
		TuneConfig.load_default().get_int("baccarat", "banker_commission_pct")
	)
	assert_int(at.get_int("blackjack", "bust_threshold")).is_equal(24)


func test_a_rule_with_no_valid_game_writes_nothing() -> void:
	var config: TuneConfig = _with_rule(
		"lost", 'game="roulette"\nside_bets.perfect_pairs=[8, 20]'
	)
	var at: TuneConfig = config.for_house_rule("lost")
	assert_array(at.get_int_list("side_bets", "perfect_pairs")).is_equal(
		TuneConfig.load_default().get_int_list("side_bets", "perfect_pairs")
	)
