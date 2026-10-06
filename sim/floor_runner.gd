class_name FloorRunner
extends RefCounted
## Plays one floor with one bot (spec §6.1–6.3, §12): no shop, items or
## marker. The bot sits at a fresh table of game, at its preferred stakes or
## at low stakes when the bankroll can't cover them, until the bankroll
## reaches the quota (it cashes out), the floor's clock runs out, or the
## bankroll can't cover a low-stakes table. A back-off or going broke at a
## table moves it to the next one; each table's heat above the floor rolls
## into run heat. The whole floor's randomness comes from seed.


## start_bankroll on floor 1; later floors start at the previous quota.
static func starting_bankroll(config: TuneConfig, floor_number: int) -> int:
	if floor_number == 1:
		return config.get_int("floors", "start_bankroll")
	return config.get_int_list("floors", "quotas")[floor_number - 2]


## bankroll SimOptions.DEFAULT_BANKROLL means the floor's starting bankroll.
static func run(
	config: TuneConfig,
	bot_name: String,
	game: GameKind.Kind,
	stakes: TableStakes.Kind,
	floor_number: int,
	bankroll: int,
	seed: int
) -> FloorResult:
	var result: FloorResult = FloorResult.new()
	result.bankroll = (
		starting_bankroll(config, floor_number)
		if bankroll == SimOptions.DEFAULT_BANKROLL
		else bankroll
	)
	var quota: int = config.get_int_list("floors", "quotas")[floor_number - 1]
	var clock: int = config.get_int("clock", "hands_per_floor")
	var rng: GameRng = GameRng.new(seed)
	var deck_rules: DeckRules = DeckRules.from_config(config)
	var deck: Deck = Deck.standard(deck_rules.min_size)
	var layer: ManipulationLayer = ManipulationLayer.new()
	var kit: ActionKit = ActionKit.everything()
	while result.bankroll < quota and result.hands < clock:
		var table: Table = _table(config, game, stakes, floor_number, result.bankroll)
		if table == null:
			break
		var session: TableSession = TableSession.new(
			config, table, deck, layer, kit, rng, result.bankroll,
			HeatFloor.of(deck, kit, deck_rules)
		)
		var bot: Bot = BotRoster.build([bot_name])[0]
		bot.begin_session(session, config, deck)
		result.tables += 1
		while session.ended() == null and session.bankroll < quota and result.hands < clock:
			var hand: HandActions = session.start_hand(
				bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
			)
			if hand == null:
				push_error("FloorRunner: %s opened a refused bet" % bot_name)
				break
			bot.play_hand(session, hand)
			session.finish_hand()
			result.hands += 1
		var end: SessionEnd = session.stand_up()
		result.bankroll = end.bankroll
		result.run_heat += end.run_heat_added
		if end.hands_played == 0:
			break
	result.cleared = result.bankroll >= quota
	return result


## The preferred stakes' table, else low stakes, else null when the bankroll
## covers neither minimum.
static func _table(
	config: TuneConfig,
	game: GameKind.Kind,
	stakes: TableStakes.Kind,
	floor_number: int,
	bankroll: int
) -> Table:
	for kind: TableStakes.Kind in [stakes, TableStakes.Kind.LOW]:
		var table: Table = Table.from_config(config, game, kind, floor_number)
		if bankroll >= table.table_min:
			return table
	return null
