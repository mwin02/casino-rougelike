extends GdUnitTestSuite
## The bet buttons (spec §1.3): the opening bet within the table and the
## bankroll between hands, and adjusts within the adjust limits in a hand.
## Floor 1 low stakes, $1,000–4,000. Baccarat piles deal P, B, P, B.

const NATURAL: Array[String] = ["9S", "2H", "KD", "3C"]

var _fixture: TableSessionFixture
var _session: TableSession
var _bets: TableBetVM


func _sit(game: GameKind.Kind = GameKind.Kind.BACCARAT, bankroll: int = 50000) -> void:
	_fixture = TableSessionFixture.new()
	_session = _fixture.sit(game, NATURAL, bankroll)
	_bets = TableBetVM.new(_session)


func _deal() -> BaccaratRound:
	_session.start_hand(_bets.opening_bet, _bets.side)
	_bets.start_hand(GameTableVM.for_round(_session.current_round(), _fixture.layer))
	return _session.current_round()


func _enabled(label: String) -> bool:
	for choice: Choice in _bets.choices():
		if choice.label == label:
			return choice.enabled
	return false


func test_opening_bet_starts_at_the_table_minimum() -> void:
	_sit()
	assert_str(_bets.text()).is_equal("Opening bet $1,000")
	assert_bool(_enabled("-")).is_false()
	assert_bool(_enabled("Min")).is_false()


func test_opening_bet_steps_by_the_table_minimum_within_the_table() -> void:
	_sit()
	_bets.press(TableBetVM.Bet.UP)
	assert_str(_bets.text()).is_equal("Opening bet $2,000")
	_bets.press(TableBetVM.Bet.MAX)
	assert_str(_bets.text()).is_equal("Opening bet $4,000")
	assert_bool(_enabled("+")).is_false()
	_bets.press(TableBetVM.Bet.MIN)
	assert_str(_bets.text()).is_equal("Opening bet $1,000")


func test_opening_bet_never_passes_the_bankroll() -> void:
	_sit(GameKind.Kind.BACCARAT, 2500)
	_bets.press(TableBetVM.Bet.MAX)
	assert_str(_bets.text()).is_equal("Opening bet $2,500")


func test_side_is_chosen_only_at_baccarat_before_the_deal() -> void:
	_sit()
	_bets.choose_side(BaccaratRound.BetSide.BANKER)
	var sides: Array[String] = []
	for choice: Choice in _bets.side_choices():
		sides.append(choice.label)
	assert_array(sides).contains_exactly(["Player", "Banker", "Tie"])
	_deal()
	assert_str(_bets.text()).is_equal("Bet $1,000 on Banker")
	_bets.choose_side(BaccaratRound.BetSide.PLAYER)
	assert_str(_bets.text()).is_equal("Bet $1,000 on Banker")
	_sit(GameKind.Kind.BLACKJACK)
	assert_array(_bets.side_choices()).is_empty()


func test_bet_moves_only_in_an_adjust() -> void:
	_sit()
	var rnd: BaccaratRound = _deal()
	assert_bool(_enabled("+")).is_false()
	rnd.proceed()
	_bets.press(TableBetVM.Bet.UP)
	assert_str(_bets.text()).is_equal("Bet $2,000 on Player")
	assert_bool(_enabled("Reset")).is_true()
	_bets.press(TableBetVM.Bet.RESET)
	assert_str(_bets.text()).is_equal("Bet $1,000 on Player")


func test_adjust_stays_within_the_raise_cap() -> void:
	_sit()
	_deal().proceed()
	_bets.press(TableBetVM.Bet.MAX)
	assert_str(_bets.text()).is_equal("Bet $3,000 on Player")


func test_no_adjust_once_the_bet_is_locked() -> void:
	_sit()
	var rnd: BaccaratRound = _deal()
	rnd.lock_bet()
	rnd.proceed()
	for choice: Choice in _bets.choices():
		assert_bool(choice.enabled).is_false()


func test_after_a_hand_the_opening_bet_fits_the_bankroll() -> void:
	_sit(GameKind.Kind.BACCARAT, 4000)
	_bets.press(TableBetVM.Bet.MAX)
	_bets.choose_side(BaccaratRound.BetSide.BANKER)
	_deal()
	TableSessionFixture.play_out(_session)
	_session.finish_hand()
	_bets.end_hand()
	assert_str(_bets.text()).is_equal("Opening bet $1,000")
