extends GdUnitTestSuite
## A real table session reshuffles the deck every hand (spec §4.1) from the
## run's shuffle stream, so a seed replays the same hands.

const SEED: int = 31337


func _session(run_seed: int) -> TableSession:
	var config: TuneConfig = TuneConfig.load_default()
	var table: Table = Table.from_config(config, GameKind.Kind.BLACKJACK, TableStakes.Kind.LOW, 1)
	return TableSession.new(
		config,
		table,
		Deck.standard(config.get_int("deck", "min_size")),
		ManipulationLayer.new(),
		ActionKit.starting(),
		GameRng.new(run_seed),
		TableSessionFixture.BANKROLL,
		0.0
	)


func _dealt_ids(session: TableSession) -> Array[int]:
	session.start_hand(session.table.table_min)
	var rnd: BlackjackRound = session.current_round()
	var cards: Array[Card] = rnd.hands[0].cards.duplicate()
	cards.append_array(rnd.dealer_hand.cards)
	cards.append_array(rnd.upcoming(10))
	return ActionsFixture.ids(cards)


func test_same_seed_deals_the_same_hand() -> void:
	assert_array(_dealt_ids(_session(SEED))).is_equal(_dealt_ids(_session(SEED)))


func test_deals_a_shuffled_deck() -> void:
	var ids: Array[int] = _dealt_ids(_session(SEED))
	var in_order: Array[int] = []
	in_order.assign(range(ids.size()))
	assert_array(ids).is_not_equal(in_order)
