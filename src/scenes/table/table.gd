extends Control
## The real table screen (U2). Draws TableScreenVM to the design canvas and
## forwards every press to it: the room and felt, the cards, the standing
## panels, and one panel per stage of a hand.

## Space kept under the bottom row.
const BOTTOM_GAP: float = 14.0
## Space kept between the heat meter and the bet under it.
const METER_GAP: float = 6.0
## Where each game's name is printed on the felt, clear of its cards.
const FELT_TITLE_Y: Dictionary[GameKind.Kind, float] = {
	GameKind.Kind.BLACKJACK: 222.0,
	GameKind.Kind.BACCARAT: 332.0,
	GameKind.Kind.HIGH_LOW: 352.0,
}
const DEBUG_SCENE: String = "res://src/scenes/table_debug.tscn"

var _vm: TableScreenVM
## An empty list: a ternary with a bare [] would lose the element type.
var _no_targets: Array[Choice] = []
var _frame: DesignFrame
var _room: TableRoom
var _cards: TableCards
var _hud: TableHud
var _choose: ChoosePanel
var _stake: StakePanel
var _side_bets: SideBetsPanel
var _pile: ChipPile
var _previous: Button
var _deal: Button
var _leave: Button
var _hand: HandPanel
var _bet: BetPill
var _next: Button
var _settle: SettlePanel
var _continue: Button
## The eye in the sky: open only in a window, by the hand panel's button.
var _eye_open: bool = false
var _eye_overlay: EyeOverlay
var _eye: EyePanel
var _eye_close: Button
## The deck screen (spec §4.4): opens over the table at any stage.
var _deck: Button
var _deck_panel: DeckPanel


func _ready() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	var run_seed: int = seed_source.randi()
	print("table: run seed ", run_seed)
	var deck: Deck = Deck.standard(DeckRules.from_config(config).min_size)
	_vm = TableScreenVM.new(config, deck, GameRng.new(run_seed))
	_build()
	_refresh()


func _build() -> void:
	var night: ColorRect = ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	_frame = DesignFrame.new()
	add_child(_frame)
	_room = _layer(TableRoom.new())
	_cards = _layer(TableCards.new())
	_hud = _layer(TableHud.new())
	_choose = ChoosePanel.new()
	_choose.position = Vector2((DesignFrame.SIZE.x - ChoosePanel.WIDTH) / 2.0, 74.0)
	_choose.changed.connect(_refresh)
	_choose.sat_down.connect(_on_sit_down)
	_choose.debug_wanted.connect(_on_debug)
	_frame.add_child(_choose)
	_stake = StakePanel.new()
	_stake.position = Vector2(TableHud.GUTTER, 82.0)
	_stake.changed.connect(_refresh)
	_frame.add_child(_stake)
	_side_bets = SideBetsPanel.new()
	_side_bets.position = Vector2(DesignFrame.SIZE.x - TableHud.GUTTER - SideBetsPanel.WIDTH, 82.0)
	_side_bets.changed.connect(_refresh)
	_frame.add_child(_side_bets)
	_pile = ChipPile.new()
	_pile.size = Vector2(150.0, 50.0)
	_frame.add_child(_pile)
	_previous = UiKit.button("", false, 13)
	_previous.pressed.connect(_on_previous)
	_frame.add_child(_previous)
	_deal = UiKit.button("Deal", true, 20)
	_deal.custom_minimum_size = Vector2(StakePanel.WIDTH, 52.0)
	_deal.pressed.connect(_on_deal)
	_frame.add_child(_deal)
	_deck = UiKit.button("Deck", false, 13)
	_deck.position = Vector2(260.0, 20.0)
	_deck.pressed.connect(_on_deck.bind(1))
	_frame.add_child(_deck)
	_deck.reset_size()
	_leave = UiKit.button("Leave table", false, 13)
	_leave.position = Vector2(_deck.position.x + _deck.size.x + 8.0, 20.0)
	_leave.pressed.connect(_on_leave)
	_frame.add_child(_leave)
	var right: float = DesignFrame.SIZE.x - TableHud.GUTTER
	_hand = HandPanel.new()
	_hand.position = Vector2(right - HandPanel.WIDTH, 90.0)
	_hand.played.connect(_on_play)
	_hand.eye_wanted.connect(_on_eye.bind(1))
	_frame.add_child(_hand)
	_bet = BetPill.new()
	_bet.changed.connect(_refresh)
	_frame.add_child(_bet)
	_next = UiKit.button("", false, 16)
	_next.custom_minimum_size.y = BetPill.HEIGHT
	_next.pressed.connect(_on_next)
	_frame.add_child(_next)
	_settle = SettlePanel.new()
	_settle.position = Vector2(right - SettlePanel.WIDTH, 84.0)
	_frame.add_child(_settle)
	_continue = UiKit.button("Continue", true, 17)
	_continue.custom_minimum_size.y = BetPill.HEIGHT
	_continue.pressed.connect(_on_continue)
	_frame.add_child(_continue)
	_eye_overlay = _layer(EyeOverlay.new())
	_eye_overlay.picked.connect(_on_eye_pick)
	_frame.move_child(_eye_overlay, _cards.get_index() + 1)
	_eye = EyePanel.new()
	_eye.position = Vector2(right + 4.0 - EyePanel.WIDTH, 52.0)
	_eye.changed.connect(_refresh)
	_frame.add_child(_eye)
	_eye_close = UiKit.button("Back to table", false, 15)
	_eye_close.custom_minimum_size.y = BetPill.HEIGHT
	_eye_close.pressed.connect(_on_eye.bind(0))
	_frame.add_child(_eye_close)
	_deck_panel = _layer(DeckPanel.new())
	_deck_panel.visible = false
	_deck_panel.closed.connect(_on_deck.bind(0))
	_frame.resized.connect(_lay_out)
	_lay_out()


## Keeps the bottom row on the frame's bottom edge, however tall it is: Deal,
## the chip pile and Prev bet above it, and the side bets down to it.
func _lay_out() -> void:
	var bottom: float = _frame.size.y - BOTTOM_GAP
	_deal.position = Vector2(TableHud.GUTTER, bottom - _deal.custom_minimum_size.y)
	_pile.position = Vector2(TableHud.GUTTER + 8.0, _deal.position.y - 6.0 - _pile.size.y)
	_previous.reset_size()
	_previous.position = Vector2(
		TableHud.GUTTER + StakePanel.WIDTH - _previous.size.x,
		_deal.position.y - 8.0 - _previous.size.y
	)
	_bet.position = Vector2(TableHud.GUTTER, bottom - BetPill.HEIGHT)
	_eye_close.position = _bet.position
	_hud.fit_meter(_bet.position.y - METER_GAP)
	for button: Button in [_next, _continue]:
		button.reset_size()
		button.position = Vector2(
			DesignFrame.SIZE.x - TableHud.GUTTER - button.size.x, bottom - button.size.y
		)
	_side_bets.custom_minimum_size.y = bottom - _side_bets.position.y
	_side_bets.reset_size()
	for layer: Control in [_room, _cards, _hud, _eye_overlay, _deck_panel]:
		layer.size = _frame.size


## Adds a control that fills the design frame.
func _layer(layer: Control) -> Control:
	layer.size = Vector2(DesignFrame.SIZE)
	_frame.add_child(layer)
	return layer


func _refresh() -> void:
	var stage: TableScreenVM.Stage = _vm.stage()
	var choosing: bool = stage == TableScreenVM.Stage.CHOOSE
	var felt: PackedStringArray = _vm.felt_lines() if not choosing else PackedStringArray()
	_room.show_felt(felt, FELT_TITLE_Y[_vm.setup.game])
	_hud.visible = not choosing
	_hud.refresh(_vm)
	_choose.visible = choosing
	_choose.refresh(_vm)
	var game: GameTableVM = _vm.game()
	var staking: bool = stage == TableScreenVM.Stage.STAKE
	_hud.show_meter(not staking)
	_stake.visible = staking
	_side_bets.visible = staking
	if staking:
		_stake.refresh(_vm)
		_side_bets.refresh(_vm)
		_deal.text = "Deal   %s" % MoneyFormat.format(_vm.stake().total())
		var stake: StakeVM = _vm.stake()
		_pile.show_amount(_vm.bets.opening_bet, 34.0, 3.0)
		_previous.text = "Prev bet  " + stake.previous_text()
		_previous.disabled = not stake.can_use_previous()
		_lay_out()
	_leave.visible = staking
	_leave.disabled = not _vm.can_stand_up()
	var playing: bool = _vm.in_hand()
	_eye_open = _eye_open and stage == TableScreenVM.Stage.WINDOW
	_deck.visible = not _eye_open
	_hand.visible = playing and not _eye_open
	_hand.refresh(_vm)
	_bet.visible = playing and not _eye_open
	_bet.refresh(_vm)
	var label: String = game.proceed_label() if playing else ""
	_next.text = label
	_next.visible = playing and not _eye_open and _vm.can_proceed() and not label.is_empty()
	_hud.show_panels(not _eye_open)
	_eye_overlay.visible = _eye_open
	_eye.visible = _eye_open
	_eye_close.visible = _eye_open
	var settled: bool = stage == TableScreenVM.Stage.SETTLE
	_settle.visible = settled
	_settle.refresh(_vm)
	_continue.visible = settled
	_lay_out()
	_pile.visible = staking
	_previous.visible = staking and not _vm.stake().previous_text().is_empty()
	_deal.visible = staking
	_deal.disabled = not _vm.can_deal()
	var groups: Array[CardGroup] = []
	if game != null and not choosing and stage != TableScreenVM.Stage.STAKE:
		groups = game.card_groups()
	var box: PackedStringArray = game.felt_box() if not groups.is_empty() else PackedStringArray()
	_cards.show_groups(groups, box, game.felt_chips() if not box.is_empty() else 0)
	if _eye_open:
		var picker: ActionPicker = _vm.picker()
		var picking_card: bool = picker.step() in [ActionPicker.Step.CARD, ActionPicker.Step.OTHER_CARD]
		var targets: Array[Choice] = picker.choices() if picking_card else _no_targets
		_eye_overlay.refresh(_vm.title(), targets, _cards.rects)
		_eye.refresh(_vm, _frame.size.y - _eye.position.y - BOTTOM_GAP)


## The next five are for scripts/shot, which drives the scene by method:
## pick the game at the chooser, press a bet button, show the eye's Read or
## Rig tab, switch a side bet.
func _choose_game(game: int) -> void:
	_vm.setup.choose_game(game)
	_refresh()


func _press_bet(id: int) -> void:
	_vm.press_bet(id)
	_refresh()


func _eye_tab(rig: int) -> void:
	_eye._show_tab(rig == 1)


## Picks the eye's choice at this place in its list, whatever its id.
func _eye_choice(index: int) -> void:
	_on_eye_pick(_vm.picker().choices()[index].id)


func _toggle_side_bet(kind: int) -> void:
	_vm.side_bets.toggle(kind as SideBetKind.Kind)
	_refresh()


func _on_sit_down() -> void:
	_vm.sit_down()
	_refresh()


func _on_deal() -> void:
	_vm.deal()
	_refresh()


func _on_leave() -> void:
	_vm.stand_up()
	_refresh()


func _on_play(id: int) -> void:
	_vm.play(id)
	_refresh()


func _on_next() -> void:
	_vm.proceed()
	_refresh()


func _on_continue() -> void:
	_vm.continue_after_hand()
	_refresh()


## Opens (1) or closes (0) the eye in the sky.
func _on_eye(open: int) -> void:
	_eye_open = open == 1
	_vm.picker().reset()
	_refresh()


## Opens (1) or closes (0) the deck screen.
func _on_deck(open: int) -> void:
	_deck_panel.visible = open == 1
	if open == 1:
		_deck_panel.open(_vm.deck_view())


## A card tapped on the table while an action wants one.
func _on_eye_pick(id: int) -> void:
	_vm.picker().pick(id)
	_refresh()


func _on_previous() -> void:
	_vm.stake().use_previous()
	_refresh()


func _on_debug() -> void:
	get_tree().change_scene_to_file(DEBUG_SCENE)
