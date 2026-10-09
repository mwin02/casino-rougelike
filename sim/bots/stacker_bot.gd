class_name StackerBot
extends Bot
## The Stacker (spec §10, §12), at blackjack: deck composition plus side
## bets, few windows. At deck services it removes the cards that help the
## dealer most (4s, 5s and 6s), up to REMOVE_TARGET. Each hand it plays the
## table minimum on basic strategy with Perfect Pairs at the cap, which the
## smaller deck pays more often, and makes at most one Nudge: when its first
## two cards are a rank apart, it moves the first onto the second.

const REMOVE_RANKS: Array[int] = [4, 5, 6]
const REMOVE_TARGET: int = 8


## Removes REMOVE_RANKS cards until REMOVE_TARGET are gone, keeping keep.
class Plan:
	extends RunPlan

	func use_services(services: DeckServices, deck: Deck, keep: int) -> void:
		var removed: int = deck.edit_count(DeckEdit.Kind.REMOVE)
		for card: Card in deck.cards():
			if removed >= REMOVE_TARGET:
				return
			if card.rank not in REMOVE_RANKS:
				continue
			if services.bankroll - services.price(DeckServices.Service.REMOVE) < keep:
				return
			if services.remove(card.id):
				removed += 1


func bot_name() -> String:
	return "stacker"


func plays(game: GameKind.Kind) -> bool:
	return game == GameKind.Kind.BLACKJACK


func actions_used() -> Array[ActionKind.Kind]:
	return [ActionKind.Kind.NUDGE]


## Buys a bigger side bet, flat removals, a lower floor, and permanence (§9).
func run_plan() -> RunPlan:
	var plan: Plan = Plan.new()
	plan.games = [GameKind.Kind.BLACKJACK]
	plan.wishlist = [
		ItemKind.Kind.SIDE_POCKET, ItemKind.Kind.SECOND_DECK, ItemKind.Kind.FORGED_PAPERS,
		ItemKind.Kind.PERMANENT_INK,
	]
	return plan


func side_bets(session: TableSession) -> Array[SideBet]:
	var cap: int = session.side_bet_cap()
	if session.bankroll - opening_bet(session) < cap:
		return []
	return [SideBet.new(SideBetKind.Kind.PERFECT_PAIRS, cap)]


func on_window(session: TableSession, hand: HandActions) -> void:
	var rnd: BlackjackRound = session.current_round() as BlackjackRound
	if rnd == null or rnd.side_bets.is_empty() or not hand.used.is_empty():
		return
	var cards: Array[Card] = rnd.hands[0].cards
	if cards.size() != 2 or absi(cards[0].rank - cards[1].rank) != 1:
		return
	if hand.can_use(ActionKind.Kind.NUDGE):
		hand.nudge(cards[0].id, cards[1].rank - cards[0].rank)
