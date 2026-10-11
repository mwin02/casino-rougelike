class_name FloorRunner
extends RefCounted
## Plays one floor with one bot (spec §6.1–6.3, §12): no shop or marker;
## items only as given. The bot sits at a fresh table of game, at its
## preferred stakes or at low stakes when the bankroll can't cover them,
## until the bankroll reaches the quota (it cashes out), the floor's clock
## runs out, or the bankroll can't cover a low-stakes table. A back-off or
## going broke at a table moves it to the next one, and so does table heat
## reaching the player's nerve (§12), drawn once per floor. Each table's
## heat above the floor rolls into run heat, and its side-bet manipulations
## carry to the next table (§8). The whole floor's randomness comes from
## seed.


## start_bankroll on floor 1; later floors start at the previous quota.
static func starting_bankroll(config: TuneConfig, floor_number: int) -> int:
	if floor_number == 1:
		return config.get_int("floors", "start_bankroll")
	return config.get_int_list("floors", "quotas")[floor_number - 2]


## bankroll SimOptions.DEFAULT_BANKROLL means the floor's starting bankroll.
## Every table plays under house_rule when it fits the game.
static func run(
	config: TuneConfig,
	bot_name: String,
	game: GameKind.Kind,
	stakes: TableStakes.Kind,
	floor_number: int,
	bankroll: int,
	seed: int,
	items: Array[ItemKind.Kind] = [],
	house_rule: String = "",
	consumables: Array[int] = []
) -> FloorResult:
	var result: FloorResult = FloorResult.new()
	result.bankroll = (
		starting_bankroll(config, floor_number)
		if bankroll == SimOptions.DEFAULT_BANKROLL
		else bankroll
	)
	var quota: int = config.get_int_list("floors", "quotas")[floor_number - 1]
	var kit: ActionKit = harness_kit(config, items, consumables)
	var clock: int = config.get_int("clock", "hands_per_floor") + kit.extra_floor_hands
	var rng: GameRng = GameRng.new(seed)
	var deck_rules: DeckRules = DeckRules.from_config(config)
	var deck: Deck = Deck.standard(deck_rules.min_size)
	var layer: ManipulationLayer = ManipulationLayer.new()
	var nerve: Nerve = Nerve.draw(seed)
	var side_bet_manipulations: int = 0
	while result.bankroll < quota and result.hands < clock:
		var table: Table = _table(config, game, stakes, floor_number, result.bankroll)
		if table == null:
			break
		table.house_rule = house_rule
		var session: TableSession = TableSession.new(
			config, table, deck, layer, kit, rng, result.bankroll,
			HeatFloor.of(deck, kit, deck_rules)
		)
		session.carry_side_bet_manipulations(side_bet_manipulations)
		var bot: Bot = BotRoster.build([bot_name])[0]
		bot.kit = kit
		bot.begin_session(session, config, deck)
		bot.take_nerve(nerve)
		result.tables += 1
		while session.ended() == null and session.bankroll < quota and result.hands < clock:
			if bot.wants_to_stand(session):
				result.stood_up += 1
				break
			var hand: HandActions = session.start_hand(
				bot.opening_bet(session), bot.baccarat_side(session), bot.side_bets(session)
			)
			if hand == null:
				push_error("FloorRunner: %s opened a refused bet" % bot_name)
				break
			bot.play_hand(session, hand)
			session.finish_hand()
			result.hands += 1
		side_bet_manipulations = session.side_bet_manipulations()
		var end: SessionEnd = session.stand_up()
		result.bankroll = end.bankroll
		result.run_heat += end.run_heat_added
		if end.hands_played == 0:
			break
	result.cleared = result.bankroll >= quota
	return result


## Every action unlocked plus items, past the slot count if need be, and
## consumables as [Masking Tape, Cold Seals].
static func harness_kit(
	config: TuneConfig, items: Array[ItemKind.Kind], consumables: Array[int] = []
) -> ActionKit:
	var kit: ActionKit = ActionKit.everything()
	var rules: ItemRules = ItemRules.from_config(config)
	rules.slots = ItemKind.Kind.size()
	for item: ItemKind.Kind in items:
		kit.add_item(item, rules)
	if consumables.size() == 2:
		kit.masking_tape = consumables[0]
		kit.cold_seals = consumables[1]
	return kit


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
