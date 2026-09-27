class_name TableHeat
extends RefCounted
## One table session's heat (spec §1.6, §4.2, §7.1, §7.2). Starts at the heat
## floor. Each hand is priced by the tier it starts in (start_hand) and its
## heat lands at resolution (finish_hand), which also returns what the table
## did: cooling after a straight hand, a tier change, the Marked consequence,
## and backing the player off at 90.
##
## The Marked consequence is rolled hidden at sit-down, so the Pit Ledger (§9)
## can show it, and fires the first time the table reaches Marked. A new
## dealer rerolls costs here; the table session (block 7) swaps in the house
## deck.

var heat: float
## §4.2: heat starts here and cooling never goes below it.
var heat_floor: float
var costs: TableCosts
var consequence: MarkedConsequence.Kind
var consequence_fired: bool = false
## At 90 the player must leave after the hand (§7.1).
var backed_off: bool = false

var _rules: HeatRules
var _rng: GameRng
## Halves on each consecutive straight hand, back to 1 after any other (§1.6).
var _decay: float = 1.0


## floor_number is 1–5. Rolls the Marked consequence from the CONSEQUENCE stream.
static func start(
	rules: HeatRules, p_costs: TableCosts, p_heat_floor: float, floor_number: int, rng: GameRng
) -> TableHeat:
	var table: TableHeat = TableHeat.new()
	table._rules = rules
	table._rng = rng
	table.costs = p_costs
	table.heat_floor = p_heat_floor
	table.heat = p_heat_floor
	var swap_chance: float = rules.house_swap_chance[floor_number - 1]
	var roll: float = rng.stream(GameRng.Stream.CONSEQUENCE).randf()
	table.consequence = (
		MarkedConsequence.Kind.HOUSE_DECK_SWAP
		if roll < swap_chance
		else MarkedConsequence.Kind.NEW_DEALER
	)
	return table


func tier() -> HeatTier.Kind:
	return _rules.tier_of(heat)


## The next hand's heat, priced at the table's costs and current tier.
func start_hand(session: ActionSession) -> HandHeat:
	return HandHeat.new(_rules, costs, tier(), session)


## Resolves the hand's heat, adds it to the table, and returns every line the
## hand produced: its actions and multiplier, then the table's own.
func finish_hand(hand: HandHeat, rnd: GameRound) -> Array[HeatLine]:
	var straight: bool = is_straight(hand, rnd)
	hand.resolve(rnd)
	var lines: Array[HeatLine] = hand.lines.duplicate()
	var old_tier: HeatTier.Kind = tier()
	heat += hand.total()
	if straight:
		lines.append(_cool(rnd))
	else:
		_decay = 1.0
	if tier() != old_tier:
		var tier_line: HeatLine = HeatLine.for_table(HeatLine.Kind.TIER)
		tier_line.tier = tier()
		lines.append(tier_line)
	if not consequence_fired and heat >= _rules.marked_from():
		lines.append(_fire_consequence())
	if tier() == HeatTier.Kind.BACKED_OFF and not backed_off:
		backed_off = true
		lines.append(HeatLine.for_table(HeatLine.Kind.BACKED_OFF))
	return lines


## §1.6: a straight hand has no actions and no bet changes.
static func is_straight(hand: HandHeat, rnd: GameRound) -> bool:
	return hand.lines.is_empty() and rnd.bet_changes.is_empty()


## §1.6: heat × cool_rate × stake_factor(bet) × decay, stopping at the floor.
func _cool(rnd: GameRound) -> HeatLine:
	var position: float = inverse_lerp(
		float(rnd.limits.table_min), float(rnd.limits.table_max), float(rnd.total_bet())
	)
	var cooling: float = heat * _rules.cool_rate * _rules.stake_factor(position) * _decay
	var cooled: float = maxf(heat - cooling, minf(heat_floor, heat))
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.COOLING, cooled - heat)
	heat = cooled
	_decay *= 0.5
	return line


func _fire_consequence() -> HeatLine:
	consequence_fired = true
	if consequence == MarkedConsequence.Kind.NEW_DEALER:
		costs = TableCosts.roll(
			_rules, costs.game, costs.stakes, _rng.stream(GameRng.Stream.TABLE_ROLLS)
		)
	var line: HeatLine = HeatLine.for_table(HeatLine.Kind.CONSEQUENCE)
	line.consequence = consequence
	return line
