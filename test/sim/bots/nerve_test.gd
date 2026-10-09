extends GdUnitTestSuite
## A simulated player's nerve (spec §12): the table heat they stand up at,
## drawn once per player and moved a little each session.


func test_each_player_draws_a_nerve_in_range() -> void:
	for seed: int in 200:
		var nerve: Nerve = Nerve.draw(seed)
		assert_float(nerve.heat).is_between(Nerve.MIN, Nerve.MAX)


func test_the_same_seed_draws_the_same_player() -> void:
	var first: Nerve = Nerve.draw(7)
	var second: Nerve = Nerve.draw(7)
	assert_float(second.heat).is_equal(first.heat)
	assert_float(second.session_heat()).is_equal(first.session_heat())


func test_players_differ() -> void:
	var lowest: float = INF
	var highest: float = -INF
	for seed: int in 50:
		var heat: float = Nerve.draw(seed).heat
		lowest = minf(lowest, heat)
		highest = maxf(highest, heat)
	# Some leave early, some stay long.
	assert_float(highest - lowest).is_greater(Nerve.MAX - Nerve.MIN - 20.0)


func test_each_session_stays_near_the_players_nerve() -> void:
	var nerve: Nerve = Nerve.draw(3)
	for i: int in 50:
		assert_float(absf(nerve.session_heat() - nerve.heat)).is_less_equal(Nerve.JITTER)


func test_a_bot_stands_up_at_its_session_heat() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, ["10S", "10H"])
	var bot: Bot = BotRoster.build(["reveal_adjust"])[0]
	bot.take_nerve(Nerve.draw(4))
	session.table_heat.heat = bot.stand_up_heat - 0.01
	assert_bool(bot.wants_to_stand(session)).is_false()
	session.table_heat.heat = bot.stand_up_heat
	assert_bool(bot.wants_to_stand(session)).is_true()


func test_a_bot_without_a_nerve_never_stands() -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, ["10S", "10H"])
	var bot: Bot = BotRoster.build(["reveal_adjust"])[0]
	session.table_heat.heat = 1000.0
	assert_bool(bot.wants_to_stand(session)).is_false()


## Reckless play sits until backed off (§7.4, §12), and the side-bet bots
## keep their block 10 behaviour.
func test_reckless_and_side_bet_bots_never_stand(
	name: String,
	# gdlint: ignore=unused-argument
	test_parameters: Array = [
		["manipulate_max"], ["reckless_chaser"],
		["side_gambler"], ["side_chaser"], ["side_nudger"],
	]
) -> void:
	var fixture: TableSessionFixture = TableSessionFixture.new()
	var session: TableSession = fixture.sit(GameKind.Kind.BLACKJACK, ["10S", "10H"])
	var bot: Bot = BotRoster.build([name])[0]
	bot.take_nerve(Nerve.draw(4))
	session.table_heat.heat = 1000.0
	assert_bool(bot.wants_to_stand(session)).is_false()
