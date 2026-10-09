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

## Value per unit staked it raises for: heat is spent where it pays.
const RAISE_ON_EDGE: float = 0.25
## The tiers the Reader still reads in.
const READ_TIERS: Array[HeatTier.Kind] = [HeatTier.Kind.CLEAN, HeatTier.Kind.WATCHED]

## The hole card's partial answer this hand: -1 unasked, 0 no, 1 ten.
var _hole_ten: int = -1


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
	if rnd is BlackjackRound:
		_ask_hole(rnd as BlackjackRound, hand)
	else:
		reveal_subject(rnd, hand)


func hole_odds(rnd: BlackjackRound) -> Array[float]:
	if _hole_ten >= 0:
		return narrow(strategy.deck_odds(), _hole_ten == 1)
	return super(rnd)


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
