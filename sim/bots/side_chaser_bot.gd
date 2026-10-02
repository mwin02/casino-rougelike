class_name SideChaserBot
extends SideGamblerBot
## Side-bet chaser (spec §8, §12): bets like the gambler, then in every
## window keeps making the manipulation that raises the side bets' value
## most, as its side-bet heat shows before it's made, until none raises it.
## Side-bet heat prices the gain, so the largest extra cost is the largest
## gain for each action; across actions it's a rough guide. side_nudger is
## the same bot limited to Nudge.

## Manipulations per window at most.
const MAX_PER_WINDOW: int = 4


## One candidate manipulation: its extra (side-bet) heat and how to make it.
class Move:
	var extra: float = 0.0
	var make: Callable


var _name: String
var _actions: Array[ActionKind.Kind]


func _init(
	p_name: String = "side_chaser", actions: Array[ActionKind.Kind] = ActionKind.MANIPULATION
) -> void:
	_name = p_name
	_actions = actions


func bot_name() -> String:
	return _name


func on_window(session: TableSession, hand: HandActions) -> void:
	if session.current_round().side_bets.is_empty():
		return
	for i: int in MAX_PER_WINDOW:
		var best: Move = _best_move(hand)
		if best == null:
			return
		best.make.call()


func _best_move(hand: HandActions) -> Move:
	var best: Move = null
	var cards: Array[Card] = hand.targets(ActionKind.Kind.NUDGE)
	for card: Card in cards:
		var id: int = card.id
		if _may(hand, ActionKind.Kind.NUDGE):
			for step: int in [-1, 1]:
				best = _better(best, hand.nudge_cost(id, step) - hand.cost_of(ActionKind.Kind.NUDGE),
					hand.nudge.bind(id, step))
		if _may(hand, ActionKind.Kind.RECOLOUR):
			for suit: int in Card.Suit.values():
				var extra: float = (
					hand.recolour_cost(id, suit as Card.Suit)
					- hand.cost_of(ActionKind.Kind.RECOLOUR)
				)
				best = _better(best, extra, hand.recolour.bind(id, suit as Card.Suit))
		if _may(hand, ActionKind.Kind.SWITCH):
			for other: Card in cards:
				if other.id > id:
					var extra: float = (
						hand.switch_cost(id, other.id) - hand.cost_of(ActionKind.Kind.SWITCH)
					)
					best = _better(best, extra, hand.switch_cards.bind(id, other.id))
		if _may(hand, ActionKind.Kind.PALM):
			for rank: int in range(1, Card.RANK_CODES.size()):
				for suit: int in Card.Suit.values():
					var extra: float = (
						hand.palm_cost(id, rank, suit as Card.Suit)
						- hand.cost_of(ActionKind.Kind.PALM)
					)
					best = _better(best, extra, hand.palm.bind(id, rank, suit as Card.Suit))
	return best


func _may(hand: HandActions, action: ActionKind.Kind) -> bool:
	return action in _actions and hand.can_use(action)


## best, or a new move when extra is positive and larger.
func _better(best: Move, extra: float, make: Callable) -> Move:
	if extra <= 0.0 or (best != null and extra <= best.extra):
		return best
	var move: Move = Move.new()
	move.extra = extra
	move.make = make
	return move
