extends GdUnitTestSuite
## The house deck swap (spec §7.2): from the hand after the table first
## reaches Marked, it deals the casino's standard deck for the rest of the
## session. The player's edits, marks and taped changes stop working there
## (§2.3), and High or Low prices against the house deck. Card i has id i.

const OWNED_SIZE: int = 8

var _f: TableSessionFixture
var _session: TableSession


func before_test() -> void:
	_f = TableSessionFixture.new()
	_f.kit.masking_tape = 1
	_f.kit.cold_seals = 1
	_session = _f.sit(GameKind.Kind.HIGH_LOW, TableSessionFixture.repeat("5", OWNED_SIZE))


## Marks the up card (id 0) and tapes a nudge on the next (id 1).
func _set_up_the_deck() -> void:
	var actions: HandActions = _session.start_hand(TableSessionFixture.BET)
	assert_bool(actions.mark(0, 0)).is_true()
	assert_bool(actions.nudge(1, 1)).is_true()
	assert_bool(actions.tape(1)).is_true()
	TableSessionFixture.play_out(_session)
	_session.finish_hand()


## A straight hand at 65 crosses into Marked and fires the consequence.
func _reach_marked(consequence: MarkedConsequence.Kind) -> HandSummary:
	_session.table_heat.consequence = consequence
	_session.table_heat.heat = 65.0
	_session.start_hand(TableSessionFixture.BET)
	TableSessionFixture.play_out(_session)
	return _session.finish_hand()


func _next_round() -> HighLowRound:
	_session.start_hand(TableSessionFixture.BET)
	return _session.current_round()


## Every card the round deals, by code, sorted.
static func _codes(rnd: HighLowRound) -> Array[String]:
	var cards: Array[Card] = [rnd.current()]
	cards.append_array(rnd.upcoming(100))
	var codes: Array[String] = []
	for card: Card in cards:
		codes.append(card.short_name())
	codes.sort()
	return codes


static func _standard_codes() -> Array[String]:
	var codes: Array[String] = []
	for card: Card in Deck.standard(0).cards():
		codes.append(card.short_name())
	codes.sort()
	return codes


func test_swap_is_announced() -> void:
	_set_up_the_deck()
	var summary: HandSummary = _reach_marked(MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	var announced: bool = false
	for line: HeatLine in summary.lines:
		if line.kind == HeatLine.Kind.CONSEQUENCE:
			announced = line.consequence == MarkedConsequence.Kind.HOUSE_DECK_SWAP
	assert_bool(announced).is_true()
	assert_bool(_session.house_deck_swapped()).is_true()


## Edits, marks and taped changes all stop working: a plain standard 52.
func test_after_the_swap_the_table_deals_a_standard_deck() -> void:
	_set_up_the_deck()
	_reach_marked(MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	var rnd: HighLowRound = _next_round()
	assert_array(_codes(rnd)).is_equal(_standard_codes())
	assert_bool(rnd.current().is_marked()).is_false()
	assert_dict(_session.current_hand().visible_marks()).is_empty()


func test_high_low_prices_against_the_house_deck() -> void:
	_reach_marked(MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	assert_int(_next_round().remaining()).is_equal(51)


func test_house_cards_cannot_be_marked_or_sealed() -> void:
	_reach_marked(MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	var rnd: HighLowRound = _next_round()
	var actions: HandActions = _session.current_hand()
	var house_card: int = rnd.current().id
	assert_bool(actions.mark(house_card, 0)).is_false()
	var next_card: Card = rnd.window_subjects()[0]
	var step: int = 1 if next_card.rank < 13 else -1
	assert_bool(actions.nudge(next_card.id, step)).is_true()
	assert_bool(actions.seal(next_card.id)).is_false()
	assert_int(_f.kit.cold_seals).is_equal(1)
	assert_int(_f.deck.size()).is_equal(OWNED_SIZE)


func test_a_new_dealer_keeps_the_owned_deck() -> void:
	_reach_marked(MarkedConsequence.Kind.NEW_DEALER)
	assert_bool(_session.house_deck_swapped()).is_false()
	assert_int(_next_round().remaining()).is_equal(OWNED_SIZE - 1)


func test_the_next_session_deals_the_owned_deck_again() -> void:
	_reach_marked(MarkedConsequence.Kind.HOUSE_DECK_SWAP)
	_session.stand_up()
	_session = _f.again(GameKind.Kind.HIGH_LOW)
	assert_int(_next_round().remaining()).is_equal(OWNED_SIZE - 1)
