class_name HighLowRound
extends GameRound
## One High or Low round (spec §3.3), with its windows as explicit phases.
## Cards come off the front of the pile, and a chain never reshuffles.
##
## Deal one card up. Each call then has a window on the next card and the
## call itself; the first call also has an adjust between them, because the
## bet locks when the chain starts. A correct call reprices the chain value
## and offers bank or continue; a wrong call loses the stake, and a tie keeps
## half the chain value. The chain banks itself at the chain cap or when the
## pile runs out. proceed() closes the current window or adjust. The one
## adjust sets the stake the chain starts from.
##
## Calls are priced against the owned deck as it stood when the table session
## began, minus the cards drawn this chain, so manipulation isn't priced in:
## not this hand's, not taped, and not sealed or inked this session. Whether a call wins goes by the
## cards as they read. Any call is allowed, even one no owned card can win.

enum Phase { READY, WINDOW, ADJUST, CALL, DECIDE, RESOLVED }
enum Direction { HIGHER, LOWER }
enum Outcome { NONE, BANKED, LOST, TIE }

var phase: Phase = Phase.READY
## The locked bet. Starts the chain value.
var stake: int
## What banking pays back now: the stake, repriced by each correct call.
var chain_value: int
## Calls made, the current one included once it's settled.
var calls: int = 0
## Every card flipped this chain, as it read. The last one is up.
var cards: Array[Card] = []
var outcome: Outcome = Outcome.NONE

var _rules: HighLowRules
## Owned rank by card id, for every owned card not yet drawn this chain.
var _remaining: Dictionary[int, int] = {}


## priced_deck is the owned deck captured at sit-down (Deck.cards()); the
## table session (block 7) keeps it for every chain. pile is the shuffled
## dealing cards.
func _init(
	rules: HighLowRules, p_limits: BetLimits, priced_deck: Array[Card], pile: Array[Card]
) -> void:
	super(p_limits, pile)
	_rules = rules
	stake = p_limits.opening
	chain_value = stake
	for card: Card in priced_deck:
		_remaining[card.id] = card.rank


func deal() -> void:
	if phase != Phase.READY:
		return
	_draw()
	_open_window()


## The card up, as it reads.
func current() -> Card:
	return cards.back()


## Closes the current window or adjust. Only the first call has an adjust.
func proceed() -> void:
	match phase:
		Phase.WINDOW:
			phase = Phase.ADJUST if calls == 0 else Phase.CALL
		Phase.ADJUST:
			phase = Phase.CALL


func is_resolved() -> bool:
	return phase == Phase.RESOLVED


func in_window() -> bool:
	return phase == Phase.WINDOW


## Only the first call's window closes into an adjust.
func adjust_follows() -> bool:
	return phase == Phase.WINDOW and calls == 0


## Bet adjusts happen here, before the first call, while the bet isn't locked.
## The bet also locks once the chain starts.
func can_adjust() -> bool:
	return phase == Phase.ADJUST and not _bet_locked


func total_bet() -> int:
	return stake


## The next card, face down.
func window_subjects() -> Array[Card]:
	return upcoming(1) if phase == Phase.WINDOW else ([] as Array[Card])


func questions(_card: Card) -> Array[PartialQuestion.Kind]:
	return [PartialQuestion.Kind.WITHIN_THREE, PartialQuestion.Kind.RED]


func answer(question: PartialQuestion.Kind, card: Card) -> bool:
	match question:
		PartialQuestion.Kind.WITHIN_THREE:
			return PartialQuestion.is_within_three(card, current())
		PartialQuestion.Kind.RED:
			return PartialQuestion.is_red(card)
	push_error("HighLowRound.answer: not a High or Low question")
	return false


## Owned cards not yet drawn this chain.
func remaining() -> int:
	return _remaining.size()


## Remaining owned cards that would win this call against the card up.
func winners(direction: Direction) -> int:
	var up: int = current().rank
	var count: int = 0
	for rank: int in _remaining.values():
		if (rank > up) if direction == Direction.HIGHER else (rank < up):
			count += 1
	return count


## What the chain value becomes if a call in direction wins, capped at the
## chain cap.
func value_if_won(direction: Direction) -> int:
	var won: int = _rules.call_value(chain_value, winners(direction), remaining())
	return mini(won, _rules.chain_cap(stake))


## True when a call is next: in the call, or the window and adjust before it.
func call_ahead() -> bool:
	return phase in [Phase.WINDOW, Phase.ADJUST, Phase.CALL]


## Calls the next card. Named call_next because Object already has call().
func call_next(direction: Direction) -> void:
	if phase != Phase.CALL:
		return
	_bet_locked = true
	var won_value: int = value_if_won(direction)
	var up: int = current().rank
	calls += 1
	var next: int = _draw().rank
	if next == up:
		chain_value = HighLowRules.tie_value(chain_value)
		_resolve(Outcome.TIE)
	elif (next > up) != (direction == Direction.HIGHER):
		chain_value = 0
		_resolve(Outcome.LOST)
	else:
		chain_value = won_value
		if chain_value >= _rules.chain_cap(stake) or _pile.is_empty():
			_resolve(Outcome.BANKED)
		else:
			phase = Phase.DECIDE


func bank() -> void:
	if phase == Phase.DECIDE:
		_resolve(Outcome.BANKED)


func continue_chain() -> void:
	if phase == Phase.DECIDE:
		_open_window()


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	if outcome == Outcome.NONE:
		return 0
	return chain_value - stake


func _apply_adjust(amount: int) -> void:
	stake += amount
	chain_value = stake


## Only the card up is in play; earlier cards in the chain have left it.
func _dealt_cards() -> Array[Card]:
	var dealt: Array[Card] = []
	if not cards.is_empty():
		dealt.append(current())
	return dealt


func _open_window() -> void:
	_count_window()
	phase = Phase.WINDOW


func _resolve(result: Outcome) -> void:
	outcome = result
	_settle_side_bets()
	phase = Phase.RESOLVED


## The card up.
func _face_up() -> Array[Card]:
	return _dealt_cards()


## Exact rank reads the first card up (§8).
func _side_bet_cards(_bet: SideBet) -> Array[Card]:
	return cards.slice(0, 1)


func _side_bet_pays(bet: SideBet) -> int:
	if bet.kind == SideBetKind.Kind.EXACT_RANK:
		return SideBetPayout.exact_rank(_side_rules, bet.called_rank, cards[0])
	return super._side_bet_pays(bet)


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	_remaining.erase(card.id)
	cards.append(card)
	return card
