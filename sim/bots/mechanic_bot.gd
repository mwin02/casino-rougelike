class_name MechanicBot
extends ManipulateMaxBot
## The Mechanic (spec §10, §12): opens at the table midpoint and rescues a
## losing hand as manipulate-max does, then cools: COOL_HANDS straight hands
## at the table minimum. It stands up at its nerve and presses on past the
## quota, unlike manipulate-max.

const COOL_HANDS: int = 3

## Straight hands still to play before it acts again.
var cool_left: int = 0


func bot_name() -> String:
	return "mechanic"


func stands_up() -> bool:
	return true


## Buys a cheaper Nudge, faster cooling, a lower rollover and permanence (§9).
func run_plan() -> RunPlan:
	return RunPlan.of(
		actions_used(),
		[
			ItemKind.Kind.SLEIGHT, ItemKind.Kind.HOUSE_REGULAR, ItemKind.Kind.COMPED_SUITE,
			ItemKind.Kind.PERMANENT_INK,
		]
	)


func begin_session(session: TableSession, config: TuneConfig, deck: Deck) -> void:
	super(session, config, deck)
	cool_left = 0


func opening_bet(session: TableSession) -> int:
	if cool_left > 0:
		return session.table.table_min
	var midpoint: int = (session.table.table_min + session.table.table_max) / 2
	return mini(midpoint, session.bankroll)


func play_hand(session: TableSession, hand: HandActions) -> void:
	var cooling: bool = cool_left > 0
	super(session, hand)
	if cooling:
		cool_left -= 1
	elif _manipulated(hand):
		cool_left = COOL_HANDS


func on_window(session: TableSession, hand: HandActions) -> void:
	if cool_left == 0:
		super(session, hand)


func _manipulated(hand: HandActions) -> bool:
	for use: ActionUse in hand.used:
		if use.action in ActionKind.MANIPULATION:
			return true
	return false
