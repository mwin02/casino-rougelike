extends GdUnitTestSuite
## A table session keeps the bankroll (block 7): each hand settles into it,
## no bet passes it, and each hand's summary gives its dollars per heat
## (spec §1.4). Card i has id i.

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


## An all-King baccarat deck always ties: a Tie bet wins every hand.
func _tie_table() -> TableSession:
	return _f.sit(GameKind.Kind.BACCARAT, TableSessionFixture.repeat("K", 6))


func _tie_payout() -> int:
	var rules: BaccaratRules = BaccaratRules.from_config(_f.config)
	return Money.apply_ratio(TableSessionFixture.BET, rules.tie_payout_num, rules.tie_payout_den)


func test_bankroll_tracks_each_hand() -> void:
	var session: TableSession = _tie_table()
	for i: int in 2:
		session.start_hand(TableSessionFixture.BET, BaccaratRound.BetSide.TIE)
		TableSessionFixture.play_out(session)
		session.finish_hand()
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL + 2 * _tie_payout())
	assert_int(session.session_net).is_equal(2 * _tie_payout())
	assert_int(session.hands_played).is_equal(2)


## §3.3: an all-5 deck ties the first call, losing half the stake.
func test_bankroll_takes_losses() -> void:
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", 4))
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_int(summary.net).is_equal(-TableSessionFixture.BET / 2)
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL - TableSessionFixture.BET / 2)


func test_a_hand_finishes_only_once_resolved() -> void:
	var session: TableSession = _tie_table()
	session.start_hand(TableSessionFixture.BET, BaccaratRound.BetSide.TIE)
	assert_object(session.finish_hand()).is_null()
	assert_int(session.hands_played).is_equal(0)


func test_opening_bet_stays_within_the_table() -> void:
	var session: TableSession = _tie_table()
	assert_bool(session.can_start_hand(TableSessionFixture.TABLE_MIN - 1)).is_false()
	assert_bool(session.can_start_hand(TableSessionFixture.TABLE_MAX + 1)).is_false()
	assert_bool(session.can_start_hand(TableSessionFixture.TABLE_MAX)).is_true()


func test_opening_bet_stays_within_the_bankroll() -> void:
	var session: TableSession = _f.sit(
		GameKind.Kind.BACCARAT, TableSessionFixture.repeat("K", 6), 1500
	)
	assert_bool(session.can_start_hand(2000)).is_false()
	assert_object(session.start_hand(2000)).is_null()
	assert_bool(session.can_start_hand(1500)).is_true()


func test_one_hand_at_a_time() -> void:
	var session: TableSession = _tie_table()
	session.start_hand(TableSessionFixture.BET)
	assert_bool(session.can_start_hand(TableSessionFixture.BET)).is_false()


## Player 20 against a dealer 10 up: every raise is capped by the bankroll.
func test_raises_stop_at_the_bankroll() -> void:
	var session: TableSession = _f.sit(
		GameKind.Kind.BLACKJACK, TableSessionFixture.repeat("10", 8), 2500
	)
	session.start_hand(TableSessionFixture.BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	assert_int(rnd.adjust_max()).is_equal(2500)


func test_double_needs_the_bankroll_to_cover_it() -> void:
	var session: TableSession = _f.sit(
		GameKind.Kind.BLACKJACK, TableSessionFixture.repeat("10", 8), 1500
	)
	session.start_hand(TableSessionFixture.BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.proceed()
	assert_bool(rnd.can_double()).is_false()


## §1.4: "+$24,000 for 6 heat".
func test_summary_gives_dollars_per_heat() -> void:
	var session: TableSession = _tie_table()
	var actions: HandActions = session.start_hand(
		TableSessionFixture.BET, BaccaratRound.BetSide.TIE
	)
	var subject: Card = session.current_round().window_subjects()[0]
	actions.full_reveal(subject.id)
	var cost: float = actions.heat.total()
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_int(summary.net).is_equal(_tie_payout())
	assert_float(summary.heat).is_equal_approx(cost, 0.0001)
	assert_bool(summary.has_rate()).is_true()
	assert_float(summary.dollars_per_heat()).is_equal_approx(_tie_payout() / cost, 0.0001)
	assert_float(session.session_heat).is_equal_approx(cost, 0.0001)


func test_heatless_hand_has_no_rate() -> void:
	var session: TableSession = _tie_table()
	session.start_hand(TableSessionFixture.BET, BaccaratRound.BetSide.TIE)
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_float(summary.heat).is_equal(0.0)
	assert_bool(summary.has_rate()).is_false()


## Cooling is its own line (§1.4), not part of the hand's heat.
func test_summary_keeps_cooling_apart() -> void:
	var session: TableSession = _tie_table()
	session.table_heat.heat = 40.0
	session.start_hand(TableSessionFixture.BET, BaccaratRound.BetSide.TIE)
	TableSessionFixture.play_out(session)
	var summary: HandSummary = session.finish_hand()
	assert_float(summary.heat).is_equal(0.0)
	assert_float(summary.cooling).is_less(0.0)
	assert_float(session.table_heat.heat).is_equal_approx(40.0 + summary.cooling, 0.0001)
