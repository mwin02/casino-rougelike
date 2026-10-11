extends GdUnitTestSuite
## Reads at High or Low (spec §2.5, §3.3): no full reveal, and look ahead
## only in the first call's window, showing one card. The player can know
## the first call but never the chain. Partial reveals and every other
## action stay. Card i has id i.

const BET: int = TableSessionFixture.BET
const FULL_REVEAL: ActionKind.Kind = ActionKind.Kind.FULL_REVEAL
const LOOK_AHEAD: ActionKind.Kind = ActionKind.Kind.LOOK_AHEAD
const PARTIAL_REVEAL: ActionKind.Kind = ActionKind.Kind.PARTIAL_REVEAL

var _f: TableSessionFixture
var _session: TableSession


func before_test() -> void:
	_f = TableSessionFixture.new()


## A High or Low hand in its first call's window: 5 up, then 9, K, 2.
func _high_low() -> HandActions:
	_session = _f.sit(GameKind.Kind.HIGH_LOW, ["5", "9", "K", "2", "7"])
	return _session.start_hand(BET)


## Calls higher on the 9, continues, and stops in the second call's window.
func _second_window(hand: HandActions) -> HighLowRound:
	var rnd: HighLowRound = _session.current_round()
	while rnd.phase != HighLowRound.Phase.CALL:
		rnd.proceed()
	rnd.call_next(HighLowRound.Direction.HIGHER)
	rnd.continue_chain()
	assert_bool(rnd.in_window()).is_true()
	assert_bool(hand.can_use(PARTIAL_REVEAL)).is_true()
	return rnd


func test_the_config_holds_the_limits() -> void:
	var rules: HighLowRules = HighLowRules.from_config(_f.config)
	assert_bool(rules.full_reveal_allowed).is_false()
	assert_bool(rules.look_ahead_first_window_only).is_true()
	# §3.3: look ahead shows the next card only.
	assert_int(rules.look_ahead_cards).is_equal(1)


func test_full_reveal_is_refused_at_high_or_low() -> void:
	var hand: HandActions = _high_low()
	assert_bool(hand.can_use(FULL_REVEAL)).is_false()
	assert_array(hand.targets(FULL_REVEAL)).is_empty()
	assert_object(hand.full_reveal(1)).is_null()
	assert_array(hand.used).is_empty()
	assert_float(hand.heat.total()).is_equal(0.0)


func test_full_reveal_still_works_at_the_other_games() -> void:
	for game: GameKind.Kind in [GameKind.Kind.BLACKJACK, GameKind.Kind.BACCARAT]:
		_session = _f.sit(game, ["10", "9", "8", "7", "6", "5"])
		var hand: HandActions = _session.start_hand(BET)
		assert_bool(hand.can_use(FULL_REVEAL)).is_true()
		var subject: Card = _session.current_round().window_subjects()[0]
		assert_object(hand.full_reveal(subject.id)).is_not_null()


func test_look_ahead_shows_one_card_at_high_or_low() -> void:
	var hand: HandActions = _high_low()
	assert_bool(hand.can_use(LOOK_AHEAD)).is_true()
	var seen: Array[Card] = hand.look_ahead()
	assert_int(seen.size()).is_equal(1)
	assert_int(seen[0].rank).is_equal(9)


func test_look_ahead_shows_two_cards_at_the_other_games() -> void:
	_session = _f.sit(GameKind.Kind.BLACKJACK, ["10", "9", "8", "7", "6", "5"])
	var hand: HandActions = _session.start_hand(BET)
	assert_int(hand.look_ahead().size()).is_equal(HandActions.LOOK_AHEAD_CARDS)


func test_look_ahead_follows_another_action_in_the_first_window() -> void:
	var hand: HandActions = _high_low()
	var asked: Array[PartialQuestion.Kind] = [PartialQuestion.Kind.RED]
	assert_array(hand.partial_reveal(1, asked)).is_not_empty()
	assert_bool(hand.can_use(LOOK_AHEAD)).is_true()
	assert_int(hand.look_ahead().size()).is_equal(1)


func test_look_ahead_is_refused_from_the_second_call_on() -> void:
	var hand: HandActions = _high_low()
	_second_window(hand)
	assert_bool(hand.can_use(LOOK_AHEAD)).is_false()
	assert_array(hand.look_ahead()).is_empty()
	assert_array(hand.used).is_empty()


func test_the_other_actions_stay_in_every_window() -> void:
	var hand: HandActions = _high_low()
	_second_window(hand)
	for action: ActionKind.Kind in [
		PARTIAL_REVEAL, ActionKind.Kind.MARK, ActionKind.Kind.NUDGE, ActionKind.Kind.RECOLOUR,
		ActionKind.Kind.SWITCH, ActionKind.Kind.PALM,
	]:
		assert_bool(hand.can_use(action)).is_true()


func test_a_config_can_lift_the_limits() -> void:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	for line: Array in [
		["full_reveal_allowed=false", "full_reveal_allowed=true"],
		["look_ahead_first_window_only=true", "look_ahead_first_window_only=false"],
		["look_ahead_cards=1", "look_ahead_cards=2"],
	]:
		var old: String = line[0]
		var new: String = line[1]
		assert_bool(text.contains(old)).is_true()
		text = text.replace(old, new)
	_f.config = TuneConfig.parse(text)
	var hand: HandActions = _high_low()
	assert_bool(hand.can_use(FULL_REVEAL)).is_true()
	assert_int(hand.look_ahead().size()).is_equal(2)
	_second_window(hand)
	assert_bool(hand.can_use(LOOK_AHEAD)).is_true()
