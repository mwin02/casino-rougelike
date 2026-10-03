class_name BaccaratRound
extends GameRound
## One baccarat round (spec §3.2), with its windows as explicit phases.
## Cards come off the front of the pile.
##
## Deal P, B, P, B with both second cards face down, then the initial window
## and the hand's one adjust. The second cards then turn over, and a natural
## resolves at once. Otherwise a third card the player will draw gets a
## window before it's dealt, then the same for the banker's; no adjust follows
## a third-card window, since both totals already show. proceed() closes the
## current window or adjust. An adjust moves the stake or switches sides
## (Player ↔ Banker).

enum BetSide { PLAYER, BANKER, TIE }
enum Phase { READY, WINDOW, ADJUST, RESOLVED }
enum WindowKind { NONE, INITIAL, PLAYER_THIRD, BANKER_THIRD }
enum Outcome { NONE, PLAYER, BANKER, TIE }

var player_hand: BaccaratHand = BaccaratHand.new()
var banker_hand: BaccaratHand = BaccaratHand.new()
var phase: Phase = Phase.READY
var window: WindowKind = WindowKind.NONE
## The side the bet is on now.
var side: BetSide
## Dollars on the bet. A side switch never changes it.
var stake: int
## False until the initial adjust closes: both second cards are face down.
var second_cards_shown: bool = false
var outcome: Outcome = Outcome.NONE

var _rules: BaccaratRules


func _init(rules: BaccaratRules, p_side: BetSide, p_limits: BetLimits, pile: Array[Card]) -> void:
	super(p_limits, pile)
	_rules = rules
	side = p_side
	stake = p_limits.opening


func deal() -> void:
	if phase != Phase.READY:
		return
	player_hand.add(_draw())
	banker_hand.add(_draw())
	player_hand.add(_draw())
	banker_hand.add(_draw())
	_enter(Phase.WINDOW, WindowKind.INITIAL)


## Closes the current window or adjust. Closing the initial adjust turns the
## second cards over; closing a third-card window deals its card.
func proceed() -> void:
	match phase:
		Phase.WINDOW:
			match window:
				WindowKind.INITIAL:
					_enter(Phase.ADJUST, window)
				WindowKind.PLAYER_THIRD:
					player_hand.add(_draw())
					_banker_step()
				WindowKind.BANKER_THIRD:
					banker_hand.add(_draw())
					_settle()
		Phase.ADJUST:
			_show_second_cards()


## Player ↔ Banker, in an adjust, while the bet isn't locked. Tie never switches.
func can_switch_side() -> bool:
	return can_adjust() and side != BetSide.TIE


## True when a switch is allowed now or in the adjust the open window closes into.
func switch_side_ahead() -> bool:
	return adjust_ahead() and side != BetSide.TIE


## Every switch is a bet change, a switch back included (spec §3.2).
func switch_side() -> void:
	if not can_switch_side():
		return
	side = BetSide.BANKER if side == BetSide.PLAYER else BetSide.PLAYER
	bet_changes.append(BetChange.new(BetChange.Kind.SIDE_SWITCH, 0, BetChange.NO_HAND))


func is_resolved() -> bool:
	return phase == Phase.RESOLVED


func in_window() -> bool:
	return phase == Phase.WINDOW


func adjust_follows() -> bool:
	return phase == Phase.WINDOW and window == WindowKind.INITIAL


func can_adjust() -> bool:
	return phase == Phase.ADJUST and not _bet_locked


func total_bet() -> int:
	return stake


## Initial window: both face-down second cards. A third-card window: the
## incoming card.
func window_subjects() -> Array[Card]:
	var subjects: Array[Card] = []
	if phase != Phase.WINDOW:
		return subjects
	if window == WindowKind.INITIAL:
		subjects.append(player_hand.cards[1])
		subjects.append(banker_hand.cards[1])
	else:
		subjects.append_array(upcoming(1))
	return subjects


func questions(_card: Card) -> Array[PartialQuestion.Kind]:
	return [PartialQuestion.Kind.HIGH, PartialQuestion.Kind.FACE_CARD]


func answer(question: PartialQuestion.Kind, card: Card) -> bool:
	match question:
		PartialQuestion.Kind.HIGH:
			return PartialQuestion.is_baccarat_high(card)
		PartialQuestion.Kind.FACE_CARD:
			return PartialQuestion.is_face_card(card)
	push_error("BaccaratRound.answer: not a baccarat question")
	return false


## Dollars won (positive) or lost (negative) this round.
func net() -> int:
	if outcome == Outcome.NONE:
		return 0
	if outcome == Outcome.TIE:
		if side != BetSide.TIE:
			return 0
		return Money.apply_ratio(stake, _rules.tie_payout_num, _rules.tie_payout_den)
	if side == BetSide.TIE or (side == BetSide.PLAYER) != (outcome == Outcome.PLAYER):
		return -stake
	if side == BetSide.BANKER:
		return Money.apply_ratio(stake, 100 - _rules.banker_commission_pct, 100)
	return stake


func _apply_adjust(amount: int) -> void:
	stake += amount


func _dealt_cards() -> Array[Card]:
	var dealt: Array[Card] = player_hand.cards.duplicate()
	dealt.append_array(banker_hand.cards)
	return dealt


func _show_second_cards() -> void:
	second_cards_shown = true
	if player_hand.is_natural() or banker_hand.is_natural():
		_settle()
	elif BaccaratRules.player_draws(player_hand.total()):
		_enter(Phase.WINDOW, WindowKind.PLAYER_THIRD)
	else:
		_banker_step()


func _banker_step() -> void:
	if BaccaratRules.banker_draws(banker_hand.total(), player_hand.third_value()):
		_enter(Phase.WINDOW, WindowKind.BANKER_THIRD)
	else:
		_settle()


func _settle() -> void:
	var player_total: int = player_hand.total()
	var banker_total: int = banker_hand.total()
	if player_total > banker_total:
		outcome = Outcome.PLAYER
	elif banker_total > player_total:
		outcome = Outcome.BANKER
	else:
		outcome = Outcome.TIE
	_settle_side_bets()
	_enter(Phase.RESOLVED)


func _side_bet_pays(bet: SideBet) -> int:
	var own: BaccaratHand = banker_hand if bet.side == BetSide.BANKER else player_hand
	match bet.kind:
		SideBetKind.Kind.DRAGON_BONUS:
			var natural: bool = player_hand.is_natural() or banker_hand.is_natural()
			return SideBetPayout.dragon_bonus(
				_side_rules, bet.side, player_hand.total(), banker_hand.total(), natural
			)
		SideBetKind.Kind.PAIR:
			return SideBetPayout.pair(_side_rules, own.cards[0], own.cards[1])
	return super._side_bet_pays(bet)


func _enter(next_phase: Phase, next_window: WindowKind = WindowKind.NONE) -> void:
	if next_phase == Phase.WINDOW:
		_count_window()
	phase = next_phase
	window = next_window


func _draw() -> Card:
	var card: Card = _pile[0]
	_pile.remove_at(0)
	return card
