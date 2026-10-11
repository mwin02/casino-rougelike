class_name MechanicTapesBot
extends MechanicBot
## The taping Mechanic (spec §12, known risks; opt-in, no target): the
## Mechanic, keeping every High or Low change it makes with Masking Tape
## while it has any, then with a Cold Seal. Give it consumables with
## --consumables in floor mode.
##
## It answers a narrow question: does a rescue-only Mechanic gain by keeping
## its changes? It changes a card only to rescue a tied first call, never to
## skew the deck, and it calls by the sit-down price, so it can't show what
## a player who stacks the deck on purpose would make.


func bot_name() -> String:
	return "mechanic_tapes"


func on_window(session: TableSession, hand: HandActions) -> void:
	super(session, hand)
	if not session.current_round() is HighLowRound:
		return
	for card: Card in hand.keepable_cards():
		if not hand.tape(card.id):
			hand.seal(card.id)
