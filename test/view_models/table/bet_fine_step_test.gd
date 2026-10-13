extends GdUnitTestSuite
## The real table's plus and minus (block U2b): they move the bet by a tidy
## step of at most half the table minimum, on a grid of that step, and the
## side bets show compact until asked for their detail. Floor 1 low stakes,
## $1,000–4,000.

var _vm: StackedTableScreenVM


func _sit(bankroll: int = -1) -> void:
	_vm = StackedTableScreenVM.on(["7H", "5S", "7D", "9C", "K"])
	if bankroll >= 0:
		_vm.bankroll = bankroll
	_vm.setup.choose_game(GameKind.Kind.BLACKJACK)
	_vm.sit_down()


# gdlint: ignore=unused-argument
func test_the_fine_step_is_a_tidy_amount(table_min: int, step: int, test_parameters: Array = [
	[1000, 500], [3000, 1000], [5000, 2000], [9000, 2000], [27000, 10000],
	[45000, 20000], [81000, 20000], [100, 100],
]) -> void:
	assert_int(TableBetVM.fine_step(table_min)).is_equal(step)


func test_plus_and_minus_move_the_opening_bet_by_the_fine_step() -> void:
	_sit()
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.opening_bet).is_equal(1500)
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.opening_bet).is_equal(2000)
	_vm.press_bet(TableBetVM.Bet.DOWN)
	assert_int(_vm.bets.opening_bet).is_equal(1500)


func test_the_fine_step_stops_at_the_table_limits() -> void:
	_sit()
	_vm.press_bet(TableBetVM.Bet.DOWN)
	assert_int(_vm.bets.opening_bet).is_equal(1000)
	for press: int in 10:
		_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.opening_bet).is_equal(4000)


func test_a_bet_off_the_grid_steps_back_onto_it() -> void:
	_sit(2700)
	_vm.press_bet(TableBetVM.Bet.MAX)
	assert_int(_vm.bets.opening_bet).is_equal(2700)
	_vm.press_bet(TableBetVM.Bet.DOWN)
	assert_int(_vm.bets.opening_bet).is_equal(2500)
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.opening_bet).is_equal(2700)


func test_an_adjust_moves_by_the_fine_step_too() -> void:
	_sit()
	_vm.deal()
	_vm.press_bet(TableBetVM.Bet.UP)
	assert_int(_vm.bets.shown_bet()).is_equal(1500)


func test_side_bets_show_compact_until_asked_and_stay_as_set() -> void:
	_sit()
	assert_bool(_vm.side_bets.detailed).is_false()
	assert_str(_vm.side_bets.caption()).is_equal("UP TO $1,000 EACH")
	_vm.side_bets.toggle_detail()
	assert_bool(_vm.side_bets.detailed).is_true()
	assert_str(_vm.side_bets.caption()).is_equal("UP TO $1,000 EACH · NO HEAT · LOCKED ONCE DEALT")
	_vm.deal()
	assert_bool(_vm.side_bets.detailed).is_true()


func test_a_side_bet_never_steps_past_what_the_bankroll_has_left() -> void:
	_sit(1250)
	var kind: SideBetKind.Kind = SideBetKind.Kind.PERFECT_PAIRS
	_vm.side_bets.toggle(kind)
	for press: int in 10:
		_vm.side_bets.step_stake(kind, 1, _vm.stake().room())
	assert_int(_vm.side_bets.total()).is_equal(200)
	assert_bool(_vm.can_deal()).is_true()
