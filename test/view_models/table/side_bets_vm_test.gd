extends GdUnitTestSuite
## Side bets on the debug table (spec §8): one button per side bet at the
## stake window, stepping its stake by a quarter of the cap and back to none,
## plus Dragon Bonus's and Pair's side and exact rank's call. Floor 1 low
## stakes, $1,000–4,000, so the cap is $1,000.

var _vm: StackedTableDebugVM


func _sit(game: GameKind.Kind, codes: Array[String]) -> void:
	_vm = StackedTableDebugVM.on(codes)
	_vm.setup.choose_game(game)
	_vm.sit_down()


func _labels() -> Array[String]:
	var labels: Array[String] = []
	for choice: Choice in _vm.side_bets.choices():
		labels.append(choice.label)
	return labels


func _press(label: String) -> void:
	var choice: Choice = StackedTableDebugVM.find(_vm.side_bets.choices(), label)
	assert_object(choice).is_not_null()
	_vm.side_bets.press(choice.id)


func test_each_game_offers_its_own_side_bets() -> void:
	_sit(GameKind.Kind.BLACKJACK, ["7H", "5S", "7D", "9C", "K"])
	assert_array(_labels()).contains_exactly(["Perfect Pairs —", "21+3 —", "Bust It —"])
	_sit(GameKind.Kind.BACCARAT, ["K", "4", "10", "4H"])
	assert_array(_labels()).contains_exactly(
		["Dragon Bonus —", "on Player", "Pair —", "on Player"]
	)
	_sit(GameKind.Kind.HIGH_LOW, ["Q", "2"])
	assert_array(_labels()).contains_exactly(["Exact rank —", "call A"])


func test_a_stake_steps_by_a_quarter_of_the_cap_then_back_to_none() -> void:
	_sit(GameKind.Kind.BLACKJACK, ["7H", "5S", "7D", "9C", "K"])
	_press("Perfect Pairs —")
	assert_str(_labels()[0]).is_equal("Perfect Pairs $250")
	for i: int in 3:
		_press(_labels()[0])
	assert_str(_labels()[0]).is_equal("Perfect Pairs $1,000")
	_press("Perfect Pairs $1,000")
	assert_str(_labels()[0]).is_equal("Perfect Pairs —")


func test_side_and_call_cycle() -> void:
	_sit(GameKind.Kind.BACCARAT, ["K", "4", "10", "4H"])
	_press("on Player")
	assert_str(_labels()[1]).is_equal("on Banker")
	_sit(GameKind.Kind.HIGH_LOW, ["Q", "2"])
	_press("call A")
	assert_str(_labels()[1]).is_equal("call 2")


func test_side_bets_ride_the_deal_and_show_how_they_settled() -> void:
	# Player 7H 7D stands on 14 against 10 + 9: loses $1,000; Perfect Pairs
	# (coloured, 23:1) wins $5,750 on $250.
	_sit(GameKind.Kind.BLACKJACK, ["7H", "10", "7D", "9", "K", "K"])
	_press("Perfect Pairs —")
	_vm.deal()
	assert_bool(_vm.side_bets.choices()[0].enabled).is_false()
	_vm.proceed()
	_vm.play(BlackjackTableVM.Play.STAND)
	while _vm.can_proceed():
		_vm.proceed()
	assert_str(_vm.summary_text()).is_equal("+$4,750, no heat\nPerfect Pairs +$5,750")
	assert_bool(_vm.side_bets.choices()[0].enabled).is_true()


func test_deal_needs_the_bankroll_to_cover_the_side_bets() -> void:
	_vm = StackedTableDebugVM.on(["7H", "10", "7D", "9", "K", "K"])
	_vm.bankroll = 4000
	_vm.sit_down()
	_vm.bets.press(TableBetVM.Bet.MAX)
	assert_bool(_vm.can_deal()).is_true()
	_press("Perfect Pairs —")
	assert_bool(_vm.can_deal()).is_false()
