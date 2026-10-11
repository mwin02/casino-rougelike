extends GdUnitTestSuite
## The taping Mechanic (spec §12, known risks): the Mechanic, keeping each
## High or Low change with Masking Tape, or a Cold Seal once the tape is
## gone. It checks whether kept changes pay at a game priced on the deck as
## it stood at sit-down (§3.3). Opt-in, with no target.

## 7 up, 7 next: a tie the bot nudges into a win. Card i has id i.
const TIE: Array[String] = ["7S", "7H", "2D", "3C"]
const NEXT_ID: int = 1

var _fixture: TableSessionFixture


func before_test() -> void:
	_fixture = TableSessionFixture.new()
	_fixture.stakes = TableStakes.Kind.HIGH
	_fixture.kit.masking_tape = 0
	_fixture.kit.cold_seals = 0


func _play(game: GameKind.Kind, codes: Array[String]) -> HandActions:
	var session: TableSession = _fixture.sit(game, codes)
	var bot: MechanicTapesBot = MechanicTapesBot.new()
	bot.begin_session(session, _fixture.config, Deck.standard(0))
	var hand: HandActions = session.start_hand(bot.opening_bet(session), bot.baccarat_side(session))
	bot.play_hand(session, hand)
	return hand


func _nudged(hand: HandActions) -> bool:
	return hand.used.any(
		func(use: ActionUse) -> bool: return use.action == ActionKind.Kind.NUDGE
	)


func test_it_is_an_opt_in_bot() -> void:
	assert_array(BotRoster.names()).contains(["mechanic_tapes"])
	assert_array(BotRoster.default_names()).not_contains(["mechanic_tapes"])
	assert_str(BotRoster.build(["mechanic_tapes"])[0].bot_name()).is_equal("mechanic_tapes")


func test_it_tapes_a_high_or_low_change() -> void:
	_fixture.kit.masking_tape = 1
	_fixture.kit.cold_seals = 1
	var hand: HandActions = _play(GameKind.Kind.HIGH_LOW, TIE)
	assert_bool(_nudged(hand)).is_true()
	assert_bool(_fixture.layer.is_taped(NEXT_ID)).is_true()
	assert_int(_fixture.kit.masking_tape).is_equal(0)
	# Tape first: the seal is kept for when the tape runs out.
	assert_int(_fixture.kit.cold_seals).is_equal(1)


func test_it_seals_once_the_tape_is_gone() -> void:
	_fixture.kit.cold_seals = 1
	var hand: HandActions = _play(GameKind.Kind.HIGH_LOW, TIE)
	assert_bool(_nudged(hand)).is_true()
	assert_int(_fixture.kit.cold_seals).is_equal(0)
	assert_int(_fixture.deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(1)
	assert_int(_fixture.deck.card(NEXT_ID).rank).is_not_equal(7)


func test_with_neither_it_plays_as_the_mechanic() -> void:
	var hand: HandActions = _play(GameKind.Kind.HIGH_LOW, TIE)
	assert_bool(_nudged(hand)).is_true()
	assert_bool(_fixture.layer.is_taped(NEXT_ID)).is_false()
	assert_int(_fixture.deck.edit_count(DeckEdit.Kind.COLD_SEAL)).is_equal(0)


func test_it_keeps_nothing_at_the_other_games() -> void:
	# Dealer 10 + ace is a natural; the Mechanic nudges the hole card.
	_fixture.kit.masking_tape = 1
	_fixture.kit.cold_seals = 1
	var hand: HandActions = _play(
		GameKind.Kind.BLACKJACK, ["10S", "10H", "10D", "AC", "5S", "5H", "5D", "5C"]
	)
	assert_bool(_nudged(hand)).is_true()
	assert_int(_fixture.kit.masking_tape).is_equal(1)
	assert_int(_fixture.kit.cold_seals).is_equal(1)


func test_the_consumables_flag_fills_the_floor_kit() -> void:
	var options: SimOptions = SimOptions.parse(PackedStringArray(["--consumables=tape:3,seal:2"]))
	assert_array(options.problems).is_empty()
	assert_array(options.consumables).is_equal([3, 2])
	var none: Array[ItemKind.Kind] = []
	var kit: ActionKit = FloorRunner.harness_kit(
		TuneConfig.load_default(), none, options.consumables
	)
	assert_int(kit.masking_tape).is_equal(3)
	assert_int(kit.cold_seals).is_equal(2)


func test_the_consumables_flag_is_refused_outside_floor_mode() -> void:
	for mode: String in ["dph", "run"]:
		var options: SimOptions = SimOptions.parse(
			PackedStringArray(["--mode=" + mode, "--consumables=tape:1", "--sessions=1"])
		)
		assert_array(SimRun.variants_of(options)).is_empty()
	var floor: SimOptions = SimOptions.parse(
		PackedStringArray(["--mode=floor", "--consumables=tape:1", "--sessions=1"])
	)
	assert_array(SimRun.variants_of(floor)).is_not_empty()


func test_the_consumables_flag_defaults_to_none() -> void:
	var options: SimOptions = SimOptions.parse(PackedStringArray([]))
	assert_array(options.consumables).is_equal([0, 0])
	assert_array(SimOptions.parse(PackedStringArray(["--consumables=seal:4"])).consumables).is_equal(
		[0, 4]
	)


func test_a_bad_consumables_flag_is_a_problem(
	value: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [["tape"], ["glue:2"], ["tape:-1"], ["tape:x"]]
) -> void:
	var options: SimOptions = SimOptions.parse(PackedStringArray(["--consumables=" + value]))
	assert_array(options.problems).is_not_empty()
