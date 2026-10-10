class_name ReaderBot
extends RevealBot
## The Reader (spec §10, §12), the competent reader: setup at low stakes,
## payoff at high. At a low-stakes table it plays as the honest adjuster,
## acting never; in a run it skips low stakes the bankroll can rise above.
## At a high-stakes table it reads in each hand's first window while the
## table is Clean or Watched, then sizes the bet on what it learned, raising
## only on a clear edge: blackjack asks the cheaper partial question, "is
## the hole card a ten?"; baccarat and High or Low, where a yes/no answer
## doesn't settle the bet, full-reveal the key card. Once the table is
## Marked, reads cost double (§7.1) and it plays honest until it stands up.
## It never reads into a back-off: when a read and the largest raise it could
## set up would take the table to Backed off, it plays the hand honestly and
## stands up after it.

## Value per unit staked it raises for: heat is spent where it pays.
const RAISE_ON_EDGE: float = 0.25
## The tiers the Reader still reads in.
const READ_TIERS: Array[HeatTier.Kind] = [HeatTier.Kind.CLEAN, HeatTier.Kind.WATCHED]

## The hole card's partial answer this hand: -1 unasked, 0 no, 1 ten.
var _hole_ten: int = -1
var _heat_rules: HeatRules
## A read here would risk a back-off: time to leave.
var _table_spent: bool = false


func _init() -> void:
	super("reader", true)


## Odds narrowed to a ten-value card (ten true) or anything else.
static func narrow(odds: Array[float], ten: bool) -> Array[float]:
	var result: Array[float] = []
	var total: float = 0.0
	for value: int in odds.size():
		var keep: bool = value > 0 and (value == 10) == ten
		result.append(odds[value] if keep else 0.0)
		total += result[value]
	if total > 0.0:
		for value: int in result.size():
			result[value] /= total
	return result


func actions_used() -> Array[ActionKind.Kind]:
	return [ActionKind.Kind.PARTIAL_REVEAL, ActionKind.Kind.FULL_REVEAL]


## Buys a free first read, a lower rollover, and free bet cuts (§9).
## Skips low stakes it can rise above.
func run_plan() -> RunPlan:
	var plan: RunPlan = RunPlan.of(
		actions_used(),
		[ItemKind.Kind.POKER_FACE, ItemKind.Kind.COMPED_SUITE, ItemKind.Kind.QUIET_HANDS]
	)
	plan.skips_low = true
	return plan


func raise_above() -> float:
	return RAISE_ON_EDGE


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	_heat_rules = HeatRules.from_config(session.rules_config())


func wants_to_stand(session: TableSession) -> bool:
	return _table_spent or super(session)


func play_hand(session: TableSession, hand: HandActions) -> void:
	_hole_ten = -1
	super(session, hand)


func on_window(session: TableSession, hand: HandActions) -> void:
	var rnd: GameRound = session.current_round()
	if (
		rnd.window_number != 1
		or session.table.stakes != TableStakes.Kind.HIGH
		or session.table_heat.tier() not in READ_TIERS
	):
		return
	var read: ActionKind.Kind = (
		ActionKind.Kind.PARTIAL_REVEAL if rnd is BlackjackRound else ActionKind.Kind.FULL_REVEAL
	)
	if _backs_off(session, hand, read):
		_table_spent = true
	elif rnd is BlackjackRound:
		_ask_hole(rnd as BlackjackRound, hand)
	else:
		reveal_subject(rnd, hand)


func hole_odds(rnd: BlackjackRound) -> Array[float]:
	if _hole_ten >= 0:
		return narrow(strategy.deck_odds(), _hole_ten == 1)
	return super(rnd)


## True when the read plus one bet change, at the largest bet ratio (§1.1),
## would take the table's heat to Backed off (§7.1).
func _backs_off(session: TableSession, hand: HandActions, read: ActionKind.Kind) -> bool:
	var tier: float = _heat_rules.cost_multiplier(session.table_heat.tier())
	var change: float = _heat_rules.bet_change_base(session.table.game) * tier
	var worst: float = (
		(hand.cost_of(read) + change) * _heat_rules.multiplier(_heat_rules.max_ratio)
	)
	return session.table_heat.heat + worst >= _heat_rules.tier_thresholds[-1]


func _ask_hole(rnd: BlackjackRound, hand: HandActions) -> void:
	if not hand.can_use(ActionKind.Kind.PARTIAL_REVEAL):
		return
	var hole: Card = rnd.dealer_hand.cards[1]
	if hole not in rnd.window_subjects():
		return
	var asked: Array[PartialQuestion.Kind] = [PartialQuestion.Kind.TEN_CARD]
	var answers: Array[bool] = hand.partial_reveal(hole.id, asked)
	if not answers.is_empty():
		_hole_ten = int(answers[0])
