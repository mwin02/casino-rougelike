extends GdUnitTestSuite
## The bet items (spec §9): High Roller's Nerve, Side Pocket, Comp Slip and
## Signature. Tables are $1,000–4,000 and deal their deck in order, so card i
## has id i. Blackjack deals player, dealer, player, dealer.

## Player 20 against dealer 17: the player wins.
const WIN: Array[String] = ["10", "10", "10", "7", "2", "2"]
## Player 17 against dealer 20: the player loses.
const LOSE: Array[String] = ["10", "10", "7", "10", "2", "2"]
## Player 20 against dealer 20: a push.
const PUSH: Array[String] = ["10", "10", "10", "10", "2", "2"]

var _s: TableSessionFixture
var _rules: ItemRules


func before_test() -> void:
	_s = TableSessionFixture.new()
	_rules = ItemRules.from_config(_s.config)


func _add(item: ItemKind.Kind) -> void:
	_s.kit.add_item(item, _rules)


## Plays one hand at bet to the end and returns its summary.
func _hand(session: TableSession, bet: int = TableSessionFixture.BET) -> HandSummary:
	session.start_hand(bet)
	TableSessionFixture.play_out(session)
	return session.finish_hand()


func _blackjack(codes: Array[String]) -> TableSession:
	return _s.sit(GameKind.Kind.BLACKJACK, codes)


# High Roller's Nerve


func test_high_rollers_nerve_pays_more_above_the_midpoint() -> void:
	_add(ItemKind.Kind.HIGH_ROLLERS_NERVE)
	var summary: HandSummary = _hand(_blackjack(WIN), 3000)
	assert_int(_rules.high_roller_bonus_pct).is_equal(20)
	assert_int(summary.net).is_equal(3000 + 600)
	assert_int(summary.bonuses[0].item).is_equal(ItemKind.Kind.HIGH_ROLLERS_NERVE)
	assert_int(summary.bonuses[0].dollars).is_equal(600)


func test_high_rollers_nerve_pays_nothing_at_the_midpoint() -> void:
	_add(ItemKind.Kind.HIGH_ROLLERS_NERVE)
	var summary: HandSummary = _hand(_blackjack(WIN), 2500)
	assert_int(summary.net).is_equal(2500)
	assert_array(summary.bonuses).is_empty()


func test_high_rollers_nerve_pays_nothing_on_a_loss() -> void:
	_add(ItemKind.Kind.HIGH_ROLLERS_NERVE)
	assert_int(_hand(_blackjack(LOSE), 3000).net).is_equal(-3000)


# Side Pocket


func test_side_pocket_raises_the_side_bet_cap() -> void:
	var session: TableSession = _blackjack(WIN)
	assert_int(session.side_bet_cap()).is_equal(1000)
	_add(ItemKind.Kind.SIDE_POCKET)
	assert_int(_rules.side_pocket_cap_pct).is_equal(50)
	assert_int(session.side_bet_cap()).is_equal(2000)


# Comp Slip


func test_comp_slip_refunds_the_first_hand_lost() -> void:
	_add(ItemKind.Kind.COMP_SLIP)
	var session: TableSession = _blackjack(LOSE)
	var summary: HandSummary = _hand(session)
	assert_int(summary.net).is_equal(0)
	assert_int(summary.bonuses[0].item).is_equal(ItemKind.Kind.COMP_SLIP)
	assert_int(session.bankroll).is_equal(TableSessionFixture.BANKROLL)


func test_comp_slip_covers_only_the_first_hand() -> void:
	_add(ItemKind.Kind.COMP_SLIP)
	var session: TableSession = _blackjack(LOSE)
	_hand(session)
	assert_int(_hand(session).net).is_equal(-TableSessionFixture.BET)


func test_comp_slip_is_spent_by_a_first_hand_that_doesnt_lose() -> void:
	_add(ItemKind.Kind.COMP_SLIP)
	var session: TableSession = _blackjack(PUSH)
	assert_int(_hand(session).net).is_equal(0)
	# The player's 10 (id 2) becomes a 7: the next hand loses.
	_s.deck.reforge(2, 7, _s.deck.card(2).suit, DeckEdit.Kind.REFORGE_FULL)
	assert_int(_hand(session).net).is_equal(-TableSessionFixture.BET)


## The main bet lost and insurance won: the stake still comes back.
func test_comp_slip_reads_the_main_bet_not_insurance() -> void:
	_add(ItemKind.Kind.COMP_SLIP)
	var session: TableSession = _blackjack(["10", "A", "7", "K", "2", "2"])
	session.start_hand(TableSessionFixture.BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.insure(rnd.insurance_max())
	TableSessionFixture.play_out(session)
	var insurance: int = rnd.net() - rnd.main_net()
	assert_int(insurance).is_greater(0)
	var summary: HandSummary = session.finish_hand()
	assert_int(summary.net).is_equal(insurance)


## The refund is at most the opening stake: a lost double gets half back.
func test_comp_slip_refunds_at_most_the_opening_stake() -> void:
	_add(ItemKind.Kind.COMP_SLIP)
	var session: TableSession = _blackjack(["5", "10", "6", "10", "2", "2"])
	session.start_hand(TableSessionFixture.BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.proceed()
	rnd.double()
	TableSessionFixture.play_out(session)
	assert_int(session.finish_hand().net).is_equal(-TableSessionFixture.BET)


# Signature


func test_signature_pays_more_on_a_win_with_a_marked_card() -> void:
	_add(ItemKind.Kind.SIGNATURE)
	_s.build_deck(WIN)
	_s.deck.mark(0, 0)
	_s.deck.mark(2, 1)
	var summary: HandSummary = _hand(_s.again(GameKind.Kind.BLACKJACK))
	assert_int(_rules.signature_bonus_pct).is_equal(25)
	assert_int(summary.net).is_equal(1250)
	assert_int(summary.bonuses.size()).is_equal(1)


func test_signature_ignores_the_dealers_marked_cards() -> void:
	_add(ItemKind.Kind.SIGNATURE)
	_s.build_deck(WIN)
	_s.deck.mark(1, 0)
	assert_int(_hand(_s.again(GameKind.Kind.BLACKJACK)).net).is_equal(1000)


func test_signature_pays_nothing_on_a_loss() -> void:
	_add(ItemKind.Kind.SIGNATURE)
	_s.build_deck(LOSE)
	_s.deck.mark(0, 0)
	assert_int(_hand(_s.again(GameKind.Kind.BLACKJACK)).net).is_equal(-1000)


## Player 4 + 5 = 9 beats banker 2 + 3: a natural.
func test_signature_reads_the_baccarat_side_bet_on() -> void:
	_add(ItemKind.Kind.SIGNATURE)
	_s.build_deck(["4", "2", "5", "3", "2", "2"])
	_s.deck.mark(0, 0)
	assert_int(_hand(_s.again(GameKind.Kind.BACCARAT)).net).is_equal(1250)
	_s.deck.clear_mark(0)
	_s.deck.mark(1, 0)
	assert_int(_hand(_s.again(GameKind.Kind.BACCARAT)).net).is_equal(1000)


func test_signature_reads_the_high_low_chain() -> void:
	_add(ItemKind.Kind.SIGNATURE)
	_s.build_deck(["5", "9", "2", "2"])
	_s.deck.mark(1, 0)
	var session: TableSession = _s.again(GameKind.Kind.HIGH_LOW)
	session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(session)
	var won: int = session.current_round().net()
	assert_int(won).is_greater(0)
	var bonus: int = Money.apply_ratio(won, _rules.signature_bonus_pct, 100)
	assert_int(session.finish_hand().net).is_equal(won + bonus)
