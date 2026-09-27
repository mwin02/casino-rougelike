extends GdUnitTestSuite
## High or Low prices every chain against the owned deck as it stood at
## sit-down (spec §3.3): a card sealed this session keeps its old price
## until the next session. Card i has id i.

## Up card 5 (id 0), then a 5 (id 1) that gets sealed as a 6, then a 9.
const CODES: Array[String] = ["5", "5", "9"]

var _f: TableSessionFixture


func before_test() -> void:
	_f = TableSessionFixture.new()
	_f.kit.cold_seals = 1


## Seals the next card (id 1) as a 6 in the first chain, then banks.
func _seal_in_first_hand(session: TableSession) -> void:
	var actions: HandActions = session.start_hand(TableSessionFixture.BET)
	assert_bool(actions.nudge(1, 1)).is_true()
	assert_bool(actions.seal(1)).is_true()
	TableSessionFixture.play_out(session)
	session.finish_hand()


func test_sealed_card_keeps_its_old_price_this_session() -> void:
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, CODES)
	_seal_in_first_hand(session)
	assert_int(_f.deck.card(1).rank).is_equal(6)
	session.start_hand(TableSessionFixture.BET)
	var rnd: HighLowRound = session.current_round()
	# Priced as it stood at sit-down, only the 9 beats the 5 up.
	assert_int(rnd.winners(HighLowRound.Direction.HIGHER)).is_equal(1)


func test_next_session_prices_the_sealed_card() -> void:
	var session: TableSession = _f.sit(GameKind.Kind.HIGH_LOW, CODES)
	_seal_in_first_hand(session)
	var next: TableSession = _f.again(GameKind.Kind.HIGH_LOW)
	next.start_hand(TableSessionFixture.BET)
	var rnd: HighLowRound = next.current_round()
	assert_int(rnd.winners(HighLowRound.Direction.HIGHER)).is_equal(2)
