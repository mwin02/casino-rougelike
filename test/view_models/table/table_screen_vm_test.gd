extends GdUnitTestSuite
## The real table screen: its stage through a hand of each game, the HUD,
## the heat meter and the window panel. Baccarat piles deal P, B, P, B;
## blackjack piles deal player, dealer up, player, hole; floor 1 low stakes.

const BACCARAT: Array[String] = ["9S", "2H", "KD", "3C"]
const BLACKJACK: Array[String] = ["KS", "9H", "7D", "8C", "2S"]

var _vm: StackedTableScreenVM


func _sit(codes: Array[String], game: GameKind.Kind, heat_floor: float = 0.0) -> void:
	_vm = StackedTableScreenVM.on(codes)
	_vm.heat_floor = heat_floor
	_vm.setup.choose_game(game)
	_vm.sit_down()


func _finish() -> void:
	while _vm.can_proceed():
		_vm.proceed()


func test_the_stage_follows_a_baccarat_hand() -> void:
	_vm = StackedTableScreenVM.on(BACCARAT)
	_vm.setup.choose_game(GameKind.Kind.BACCARAT)
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.CHOOSE)
	_vm.sit_down()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.STAKE)
	_vm.deal()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.WINDOW)
	_finish()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)
	_vm.continue_after_hand()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.STAKE)


func test_blackjack_has_a_turn_between_its_windows() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK)
	_vm.deal()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.WINDOW)
	_vm.proceed()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.TURN)
	_vm.play(BlackjackTableVM.Play.STAND)
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.WINDOW)
	assert_str(_vm.window_tag()).is_equal("FINAL")


func test_high_or_low_settles_when_banked() -> void:
	_sit(["5S", "9S", "3S", "KS"], GameKind.Kind.HIGH_LOW)
	_vm.deal()
	assert_str(_vm.window_tag()).is_equal("NEXT CARD")
	_vm.play(HighLowTableVM.Play.HIGHER)
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.TURN)
	_vm.play(HighLowTableVM.Play.BANK)
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)


func test_a_hand_that_ends_the_session_still_settles_first() -> void:
	_sit(BACCARAT, GameKind.Kind.BACCARAT, 140.0)
	_vm.deal()
	_finish()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)
	assert_str(_vm.title()).is_equal("Baccarat")
	assert_str(_vm.meter().tier_name()).is_equal("Backed off")
	_vm.continue_after_hand()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.CHOOSE)
	assert_int(_vm.ended().reason).is_equal(SessionEnd.Reason.BACKED_OFF)


func test_the_hud_names_the_table_and_the_money() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK)
	var table: Table = _vm.session().table
	assert_str(_vm.title()).is_equal("Blackjack")
	assert_str(_vm.subtitle()).is_equal("FLOOR 1 · LOW STAKES")
	assert_str(_vm.bankroll_text()).is_equal(MoneyFormat.format(_vm.bankroll))
	assert_str(_vm.limits_text()).is_equal(
		"%s–%s" % [MoneyFormat.format(table.table_min), MoneyFormat.format(table.table_max)]
	)
	assert_str(_vm.clock_text()).is_equal("")


func test_the_felt_names_the_game_and_any_house_rule() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK)
	assert_array(_vm.felt_lines()).contains_exactly(["BLACKJACK"])
	_vm = StackedTableScreenVM.on(BLACKJACK)
	var rule: Choice = StackedTableDebugVM.find(_vm.setup.house_rule_choices(), "Bust at 23")
	_vm.setup.choose_house_rule(rule.id)
	_vm.sit_down()
	assert_int(_vm.felt_lines().size()).is_equal(2)
	assert_str(_vm.felt_lines()[1]).is_equal(
		HouseRuleText.offer_line(_vm.session().table.house_rule).to_upper()
	)


func test_the_window_panel_says_what_is_down_and_whether_the_bet_moves() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK)
	assert_str(_vm.window_tag()).is_equal("")
	_vm.deal()
	assert_str(_vm.window_tag()).is_equal("HOLE CARD")
	assert_str(_vm.window_note()).is_equal(
		"The dealer's hole card is down. Raise or lower your bet before play."
	)
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(0)
	_vm.picker().pick(ActionPicker.DOWN)
	assert_str(_vm.window_note()).is_equal("The dealer's hole card is down. Your bet is locked.")


func test_the_eye_shows_the_cheapest_usable_action_as_a_whole_number() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK)
	_vm.deal()
	var hand: HandActions = _vm.session().current_hand()
	var cheapest: float = INF
	for action: ActionKind.Kind in ActionKind.Kind.values():
		if hand.can_use(action):
			cheapest = minf(cheapest, hand.cost_of(action))
	assert_str(_vm.eye_text()).is_equal("Read or rig · from +%d heat" % roundi(cheapest))
	assert_bool(_vm.eye_text().contains(".")).is_false()


func test_the_meter_projects_this_hands_heat_then_lands_on_it() -> void:
	_sit(BLACKJACK, GameKind.Kind.BLACKJACK, 6.0)
	assert_str(_vm.meter().heat_text()).is_equal("6")
	assert_bool(_vm.meter().has_floor()).is_true()
	_vm.deal()
	assert_bool(_vm.meter().has_projection()).is_false()
	_vm.picker().pick(ActionKind.Kind.NUDGE)
	_vm.picker().pick(0)
	_vm.picker().pick(ActionPicker.DOWN)
	assert_bool(_vm.meter().has_projection()).is_true()
	assert_str(_vm.meter().heat_text()).is_equal("6")
	assert_int(_vm.receipt().rows.size()).is_equal(1)
	_finish()
	_vm.play(BlackjackTableVM.Play.STAND)
	_finish()
	assert_int(_vm.stage()).is_equal(TableScreenVM.Stage.SETTLE)
	assert_str(_vm.meter_before().heat_text()).is_equal("6")
	assert_bool(_vm.meter().has_projection()).is_false()
	assert_str(_vm.meter().heat_text()).is_equal(str(6 + _vm.receipt().total))
