# gdlint: disable=max-public-methods
# Blackjack's own plays plus the GameRound interface pass the method cap.
class_name BlackjackRound
extends GameRound
## One blackjack round (spec §3.1), with its windows as explicit phases.
## Cards come off the front of the pile.
##
## Deal, then the hole-card window and an adjust, then the player's turn. A hit
## or double opens a window on the incoming card and an adjust before the card
## is drawn. Standing opens the final window; passing it plays the dealer and
## resolves. proceed() closes the current window or adjust. An adjust sets the
## active hand's stake. There is no peek: a dealer natural is found at
## resolution and beats every stake.
##
## Splits act as extra lives: each split hand plays and settles on its own,
## and one busting doesn't end the round. Insurance is taken in the adjust
## after the hole-card window. Doubles, splits and insurance count toward the
## bet limits like an adjust (spec §1.3).

enum Phase { READY, WINDOW, ADJUST, PLAYER_TURN, RESOLVED }
enum WindowKind { NONE, HOLE_CARD, BEFORE_HIT, FINAL }
## The player draw waiting behind a window and adjust.
enum Pending { NONE, HIT, DOUBLE }

var hands: Array[BlackjackHand] = []
var active_hand_index: int = 0
var dealer_hand: BlackjackHand
var phase: Phase = Phase.READY
var window: WindowKind = WindowKind.NONE
## Dollars on insurance, or 0.
var insurance_stake: int = 0

var _rules: BlackjackRules
var _pending: Pending = Pending.NONE


func _init(rules: BlackjackRules, p_limits: BetLimits, pile: Array[Card]) -> void:
	super(p_limits, pile)
	_rules = rules
	var first: BlackjackHand = BlackjackHand.new(rules)
	first.stake = opening_bet
	hands.append(first)
	dealer_hand = BlackjackHand.new(rules)


func active_hand() -> BlackjackHand:
	return hands[active_hand_index]


## Player, dealer up, player, dealer hole. A player natural resolves at once.
func deal() -> void:
	if phase != Phase.READY:
		return
	var hand: BlackjackHand = active_hand()
	hand.add(_draw())
	dealer_hand.add(_draw())
	hand.add(_draw())
	dealer_hand.add(_draw())
	if hand.is_natural():
		var push: bool = dealer_hand.is_natural()
		hand.outcome = BlackjackHand.Outcome.PUSH if push else BlackjackHand.Outcome.NATURAL
		_enter(Phase.RESOLVED)
		return
	_enter(Phase.WINDOW, WindowKind.HOLE_CARD)


## Closes the current window or adjust.
func proceed() -> void:
	match phase:
		Phase.WINDOW:
			if window == WindowKind.FINAL:
				_play_dealer()
			else:
				_enter(Phase.ADJUST)
		Phase.ADJUST:
			if _pending == Pending.NONE:
				_enter(Phase.PLAYER_TURN)
			else:
				_draw_pending()


func can_hit() -> bool:
	return phase == Phase.PLAYER_TURN


func can_stand() -> bool:
	return can_hit()


## Doubling is a bet change, so a locked bet forbids it (spec §2.2), and it
## must fit under the raise cap.
func can_double() -> bool:
	return (
		can_hit()
		and not _bet_locked
		and active_hand().cards.size() == 2
		and total_bet() + active_hand().stake <= limits.max_total()
	)


## Same rank only, up to the hand cap. A split is a bet change (spec §2.2).
func can_split() -> bool:
	if not can_double() or hands.size() >= _rules.max_split_hands:
		return false
	var cards: Array[Card] = active_hand().cards
	return cards[0].rank == cards[1].rank


## Insurance: in the adjust after the hole-card window, with an ace up.
func can_insure() -> bool:
	return (
		phase == Phase.ADJUST
		and _pending == Pending.NONE
		and not _bet_locked
		and insurance_stake == 0
		and dealer_hand.cards[0].is_ace()
		and insurance_max() > 0
	)


## The largest insurance stake allowed: a share of the opening bet, and no
## more than the room left under the raise cap.
func insurance_max() -> int:
	var share: int = Money.apply_ratio(opening_bet, _rules.insurance_max_pct, 100)
	return maxi(mini(share, limits.max_total() - total_bet()), 0)


func hit() -> void:
	if can_hit():
		_open_draw(Pending.HIT)


func double() -> void:
	if not can_double():
		return
	var hand: BlackjackHand = active_hand()
	bet_changes.append(BetChange.new(BetChange.Kind.DOUBLE, hand.stake, active_hand_index))
	hand.stake *= 2
	hand.stake_floor = hand.stake
	hand.doubled = true
	_open_draw(Pending.DOUBLE)


## The second card moves to a new hand at the end of the list, so hand
## indices already recorded never shift. Each hand then takes a card, this
## one first, with no window: they're dealt, not hit.
func split() -> void:
	if not can_split():
		return
	var hand: BlackjackHand = active_hand()
	var new_hand: BlackjackHand = BlackjackHand.new(_rules)
	var moved: Card = hand.cards.pop_back()
	new_hand.add(moved)
	new_hand.stake = hand.stake
	new_hand.from_split = true
	hand.from_split = true
	var new_index: int = hands.size()
	hands.append(new_hand)
	bet_changes.append(BetChange.new(BetChange.Kind.SPLIT, new_hand.stake, new_index))
	hand.add(_draw())
	new_hand.add(_draw())


## amount must be between 1 and insurance_max().
func insure(amount: int) -> void:
	if not can_insure() or amount <= 0 or amount > insurance_max():
		return
	insurance_stake = amount
	bet_changes.append(BetChange.new(BetChange.Kind.INSURANCE, amount, BetChange.NO_HAND))


func stand() -> void:
	if can_stand():
		active_hand().stood = true
		_next_hand()


func in_window() -> bool:
	return phase == Phase.WINDOW


func can_adjust() -> bool:
	return phase == Phase.ADJUST and not _bet_locked


## Hole-card window: the hole card. Before a hit: the incoming card. Final
## window: the hole card and the dealer's first draw.
func window_subjects() -> Array[Card]:
	var subjects: Array[Card] = []
	if phase != Phase.WINDOW:
		return subjects
	if window in [WindowKind.HOLE_CARD, WindowKind.FINAL]:
		subjects.append(dealer_hand.cards[1])
	if window in [WindowKind.BEFORE_HIT, WindowKind.FINAL]:
		subjects.append_array(upcoming(1))
	return subjects


## "Does this bust me?" only on the incoming card, for the active hand.
func questions(card: Card) -> Array[PartialQuestion.Kind]:
	var offered: Array[PartialQuestion.Kind] = [
		PartialQuestion.Kind.TEN_CARD, PartialQuestion.Kind.RED
	]
	if phase == Phase.WINDOW and window == WindowKind.BEFORE_HIT and card in upcoming(1):
		offered.push_front(PartialQuestion.Kind.BUSTS_ME)
	return offered


func answer(question: PartialQuestion.Kind, card: Card) -> bool:
	match question:
		PartialQuestion.Kind.BUSTS_ME:
			var drawn: BlackjackHand = BlackjackHand.new(_rules)
			for held: Card in active_hand().cards:
				drawn.add(held)
			drawn.add(card)
			return drawn.is_bust()
		PartialQuestion.Kind.TEN_CARD:
			return PartialQuestion.is_ten_card(card)
		PartialQuestion.Kind.RED:
			return PartialQuestion.is_red(card)
	push_error("BlackjackRound.answer: not a blackjack question")
	return false


## Lowering moves only the active hand, and not under its floor.
func adjust_min() -> int:
	var hand: BlackjackHand = active_hand()
	return maxi(super.adjust_min(), total_bet() - hand.stake + hand.stake_floor)


## Every dollar on the table now: all hands' stakes plus insurance.
func total_bet() -> int:
	var total: int = insurance_stake
	for hand: BlackjackHand in hands:
		total += hand.stake
	return total


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	var total: int = _insurance_net()
	for hand: BlackjackHand in hands:
		total += hand.net()
	return total


func _apply_adjust(amount: int) -> void:
	active_hand().stake += amount


func _dealt_cards() -> Array[Card]:
	var dealt: Array[Card] = []
	for hand: BlackjackHand in hands:
		dealt.append_array(hand.cards)
	dealt.append_array(dealer_hand.cards)
	return dealt


func _adjust_hand_index() -> int:
	return active_hand_index


func _insurance_net() -> int:
	if insurance_stake == 0 or phase != Phase.RESOLVED:
		return 0
	if dealer_hand.is_natural():
		var num: int = _rules.insurance_payout_num
		return Money.apply_ratio(insurance_stake, num, _rules.insurance_payout_den)
	return -insurance_stake


func _open_draw(pending: Pending) -> void:
	_pending = pending
	_enter(Phase.WINDOW, WindowKind.BEFORE_HIT)


func _draw_pending() -> void:
	var hand: BlackjackHand = active_hand()
	hand.add(_draw())
	if _pending == Pending.DOUBLE:
		hand.stood = true
	_pending = Pending.NONE
	if hand.is_done():
		_next_hand()
	else:
		_enter(Phase.PLAYER_TURN)


## Moves to the next unfinished hand, or on to the final window. With every
## hand bust there is nothing left to play for, so the round resolves.
func _next_hand() -> void:
	while active_hand_index < hands.size() - 1 and active_hand().is_done():
		active_hand_index += 1
	if not active_hand().is_done():
		_enter(Phase.PLAYER_TURN)
		return
	for hand: BlackjackHand in hands:
		if not hand.is_bust():
			_enter(Phase.WINDOW, WindowKind.FINAL)
			return
	_settle()


func _play_dealer() -> void:
	if not dealer_hand.is_natural():
		while _dealer_should_hit():
			dealer_hand.add(_draw())
	_settle()


func _dealer_should_hit() -> bool:
	var dealer_total: int = dealer_hand.total()
	if dealer_total < _rules.dealer_stand:
		return true
	return dealer_total == _rules.dealer_stand and dealer_hand.is_soft() and _rules.dealer_hits_soft_17


func _settle() -> void:
	for hand: BlackjackHand in hands:
		hand.outcome = _compare(hand)
	_enter(Phase.RESOLVED)


func _compare(hand: BlackjackHand) -> BlackjackHand.Outcome:
	if hand.is_bust():
		return BlackjackHand.Outcome.PLAYER_BUST
	if dealer_hand.is_natural():
		return BlackjackHand.Outcome.LOSE
	if dealer_hand.is_bust():
		return BlackjackHand.Outcome.DEALER_BUST
	var player_total: int = hand.total()
	var dealer_total: int = dealer_hand.total()
	if player_total > dealer_total:
		return BlackjackHand.Outcome.WIN
	if player_total < dealer_total:
		return BlackjackHand.Outcome.LOSE
	return BlackjackHand.Outcome.PUSH


func _enter(next_phase: Phase, next_window: WindowKind = WindowKind.NONE) -> void:
	phase = next_phase
	window = next_window
	if next_phase == Phase.WINDOW:
		_count_window()


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	return card
