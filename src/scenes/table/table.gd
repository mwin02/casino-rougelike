extends Control
## The real table screen (U2). Draws TableScreenVM to the design canvas and
## forwards every press to it: the room and felt, the cards, the standing
## panels, and one panel per stage of a hand.

## Space kept under the bottom row.
const BOTTOM_GAP: float = 14.0
const DEBUG_SCENE: String = "res://src/scenes/table_debug.tscn"

var _vm: TableScreenVM
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
	_side_bets.custom_minimum_size.y = bottom - _side_bets.position.y
	_side_bets.reset_size()
	for layer: Control in [_room, _cards, _hud]:
		layer.size = _frame.size


## Adds a control that fills the design frame.
func _layer(layer: Control) -> Control:
	layer.size = Vector2(DesignFrame.SIZE)
	_frame.add_child(layer)
	return layer


func _refresh() -> void:
	var stage: TableScreenVM.Stage = _vm.stage()
	var choosing: bool = stage == TableScreenVM.Stage.CHOOSE
	_room.show_felt(_vm.felt_lines() if not choosing else PackedStringArray())
	_hud.visible = not choosing
	_hud.refresh(_vm)
	_choose.visible = choosing
	_choose.refresh(_vm)
	var staking: bool = stage == TableScreenVM.Stage.STAKE
	_hud.show_meter(not staking)
	_stake.visible = staking
	_side_bets.visible = staking
	if staking:
		_stake.refresh(_vm)
		_side_bets.refresh(_vm)
		_deal.text = "Deal   %s" % MoneyFormat.format(_vm.stake().total())
		var stake: StakeVM = _vm.stake()
		_pile.show_chips(stake.bet_chips(), 34.0, 5, 3.0)
		_previous.text = "Prev bet  " + stake.previous_text()
		_previous.disabled = not stake.can_use_previous()
		_lay_out()
	_pile.visible = staking
	_previous.visible = staking and not _vm.stake().previous_text().is_empty()
	_deal.visible = staking
	_deal.disabled = not _vm.can_deal()
	var game: GameTableVM = _vm.game()
	var groups: Array[CardGroup] = []
	if game != null and not choosing and stage != TableScreenVM.Stage.STAKE:
		groups = game.card_groups()
	_cards.show_groups(groups)


func _on_sit_down() -> void:
	_vm.sit_down()
	_refresh()


func _on_deal() -> void:
	_vm.deal()
	_refresh()


func _on_previous() -> void:
	_vm.stake().use_previous()
	_refresh()


func _on_debug() -> void:
	get_tree().change_scene_to_file(DEBUG_SCENE)
