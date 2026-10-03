extends GdUnitTestSuite
## The bots' blackjack strategy: expected values under the table's own rules
## (spec §3.1: 22 busts, dealer hits soft 17, no peek), card odds taken from
## the deck's composition.

var _config: TuneConfig = TuneConfig.load_default()


func _engine(bust_threshold: int = 0) -> BlackjackEv:
	var rules: BlackjackRules = BlackjackRules.from_config(_config)
	if bust_threshold > 0:
		rules.bust_threshold = bust_threshold
	return BlackjackEv.from_cards(rules, Deck.standard(0).cards())


func _cards(codes: Array[String]) -> Array[Card]:
	var cards: Array[Card] = []
	for code: String in codes:
		cards.append(Card.parse(code))
	return cards


func _decide(
	engine: BlackjackEv, hand: Array[String], up: String, can_double: bool = true
) -> BlackjackEv.Play:
	return engine.decide(_cards(hand), Card.parse(up), engine.deck_odds(), can_double, true)


func test_dealer_outcomes_sum_to_one() -> void:
	var engine: BlackjackEv = _engine()
	for up: String in ["AS", "6H", "KD"]:
		var outcomes: Array[float] = engine.dealer_outcomes(Card.parse(up), engine.deck_odds())
		var total: float = 0.0
		for p: float in outcomes:
			total += p
		assert_float(total).is_equal_approx(1.0, 1e-9)


func test_dealer_natural_odds_come_from_the_deck() -> void:
	var engine: BlackjackEv = _engine()
	var ace_up: Array[float] = engine.dealer_outcomes(Card.parse("AS"), engine.deck_odds())
	var ten_up: Array[float] = engine.dealer_outcomes(Card.parse("KS"), engine.deck_odds())
	assert_float(ace_up[engine.natural_index()]).is_equal_approx(16.0 / 52.0, 1e-9)
	assert_float(ten_up[engine.natural_index()]).is_equal_approx(4.0 / 52.0, 1e-9)


func test_stand_on_the_best_total() -> void:
	var engine: BlackjackEv = _engine()
	for up: String in ["AS", "6H", "10D"]:
		assert_int(_decide(engine, ["KS", "QH", "2D"], up)).is_equal(BlackjackEv.Play.STAND)


func test_double_eleven_against_a_six() -> void:
	assert_int(_decide(_engine(), ["5S", "6H"], "6D")).is_equal(BlackjackEv.Play.DOUBLE)


func test_no_double_when_the_table_refuses_it() -> void:
	var play: BlackjackEv.Play = _decide(_engine(), ["5S", "6H"], "6D", false)
	assert_int(play).is_equal(BlackjackEv.Play.HIT)


func test_bust_threshold_changes_hard_twelve() -> void:
	# At 22, twelve against a four stands (the usual basic strategy); at 23
	# no single card can bust it, so it hits (doubling, when allowed).
	assert_int(_decide(_engine(22), ["10S", "2H"], "4D", false)).is_equal(BlackjackEv.Play.STAND)
	assert_int(_decide(_engine(23), ["10S", "2H"], "4D", false)).is_equal(BlackjackEv.Play.HIT)


func test_never_split_tens() -> void:
	assert_int(_decide(_engine(), ["10S", "10H"], "6D")).is_equal(BlackjackEv.Play.STAND)


func test_a_known_hole_card_changes_the_play() -> void:
	# Nineteen stands against a ten up, but hits once the hole shows the
	# dealer holds twenty.
	var engine: BlackjackEv = _engine()
	var hand: Array[Card] = _cards(["10S", "9H"])
	var unknown: BlackjackEv.Play = engine.decide(
		hand, Card.parse("10D"), engine.deck_odds(), true, true
	)
	var known: BlackjackEv.Play = engine.decide(
		hand, Card.parse("10D"), BlackjackEv.known(Card.parse("KC")), true, true
	)
	assert_int(unknown).is_equal(BlackjackEv.Play.STAND)
	assert_int(known).is_equal(BlackjackEv.Play.HIT)


func test_hand_value_is_the_best_play() -> void:
	var engine: BlackjackEv = _engine()
	var hand: Array[Card] = _cards(["10S", "9H"])
	var up: Card = Card.parse("6D")
	var value: float = engine.hand_value(hand, up, engine.deck_odds(), true, true)
	assert_float(value).is_equal_approx(engine.stand_value(19, up, engine.deck_odds()), 1e-9)
	assert_float(value).is_greater(0.0)
