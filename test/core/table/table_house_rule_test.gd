extends GdUnitTestSuite
## A table may play under a house rule (spec §5.2): its session reads the
## game's rules through the rule's config. Bust at 23 (§3.1) makes a 22 a
## live total and leaves the dealer's stand point alone. Card i has id i.

const BET: int = TableSessionFixture.BET
const RULE: String = "bust_23"

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()


## Sits at a blackjack table under RULE, or under no rule.
func _sit(codes: Array[String], rule: String = RULE) -> TableSession:
	_f.house_rule = rule
	return _f.sit(GameKind.Kind.BLACKJACK, codes)


## Deals a hand and takes the player to their turn.
func _to_turn(session: TableSession) -> BlackjackRound:
	session.start_hand(BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.proceed()
	return rnd


func test_a_table_keeps_its_house_rule() -> void:
	var table: Table = Table.new(GameKind.Kind.BLACKJACK, TableStakes.Kind.LOW, 1, 1000, 4000)
	assert_str(table.house_rule).is_empty()
	table.house_rule = RULE
	assert_str(Table.from_dict(table.to_dict()).house_rule).is_equal(RULE)


func test_a_table_with_no_rule_reads_the_config_as_given() -> void:
	var table: Table = _f.table(GameKind.Kind.BLACKJACK)
	assert_object(table.rules_config(_f.config)).is_same(_f.config)


func test_a_tables_rule_is_written_into_its_config() -> void:
	_f.house_rule = RULE
	var config: TuneConfig = _f.table(GameKind.Kind.BLACKJACK).rules_config(_f.config)
	assert_array(config.applied_house_rules()).is_equal([RULE])
	# §3.1: the house rule is a bust at 23.
	assert_int(config.get_int("blackjack", "bust_threshold")).is_equal(23)


func test_a_rule_for_another_game_is_ignored() -> void:
	_f.house_rule = RULE
	var table: Table = _f.table(GameKind.Kind.BACCARAT)
	assert_object(table.rules_config(_f.config)).is_same(_f.config)


func test_a_rule_the_config_lacks_is_ignored() -> void:
	_f.house_rule = "no_such_rule"
	var table: Table = _f.table(GameKind.Kind.BLACKJACK)
	assert_object(table.rules_config(_f.config)).is_same(_f.config)


func test_a_22_stands_and_wins_at_a_bust_23_table() -> void:
	# Player 10 + 5, hits a 7 for 22; dealer 10 + 8 stands on 18.
	var session: TableSession = _sit(["10", "10", "5", "8", "7"])
	var rnd: BlackjackRound = _to_turn(session)
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.active_hand().total()).is_equal(22)
	assert_bool(rnd.active_hand().is_bust()).is_false()
	BlackjackRoundFixture.stand(rnd)
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(session.finish_hand().net).is_equal(BET)


func test_the_same_22_busts_at_a_table_with_no_rule() -> void:
	var session: TableSession = _sit(["10", "10", "5", "8", "7"], "")
	var rnd: BlackjackRound = _to_turn(session)
	BlackjackRoundFixture.hit(rnd)
	assert_bool(rnd.is_resolved()).is_true()
	assert_int(session.finish_hand().net).is_equal(-BET)


func test_a_23_busts_at_a_bust_23_table() -> void:
	var session: TableSession = _sit(["10", "10", "5", "8", "8"])
	var rnd: BlackjackRound = _to_turn(session)
	BlackjackRoundFixture.hit(rnd)
	assert_int(session.finish_hand().net).is_equal(-BET)


func test_aces_count_high_up_to_22() -> void:
	# §3.1: each ace counts 11 while the total stays under the bust threshold.
	var session: TableSession = _sit(["A", "10", "A", "8", "10"])
	var rnd: BlackjackRound = _to_turn(session)
	assert_int(rnd.active_hand().total()).is_equal(22)
	assert_bool(rnd.active_hand().is_soft()).is_true()
	BlackjackRoundFixture.hit(rnd)
	assert_int(rnd.active_hand().total()).is_equal(22)
	assert_bool(rnd.active_hand().is_soft()).is_true()


func test_the_dealer_still_stands_on_17() -> void:
	# §3.1: the stand point does not move with the bust threshold.
	var session: TableSession = _sit(["10", "10", "9", "7", "2", "2"])
	var rnd: BlackjackRound = _to_turn(session)
	BlackjackRoundFixture.stand(rnd)
	assert_int(rnd.dealer_hand.cards.size()).is_equal(2)
	assert_int(session.finish_hand().net).is_equal(BET)


func test_the_dealers_22_beats_a_20() -> void:
	# Dealer 10 + 6 draws a 6: 22 stands under the rule and wins.
	var session: TableSession = _sit(["10", "10", "10", "6", "6"])
	var rnd: BlackjackRound = _to_turn(session)
	BlackjackRoundFixture.stand(rnd)
	assert_bool(rnd.dealer_hand.is_bust()).is_false()
	assert_int(session.finish_hand().net).is_equal(-BET)
