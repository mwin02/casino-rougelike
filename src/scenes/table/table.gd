extends Control
## The real table screen (U2). Draws TableScreenVM to the design canvas and
## forwards every press to it: the room and felt, the cards, the standing
## panels, and one panel per stage of a hand.

const DEBUG_SCENE: String = "res://src/scenes/table_debug.tscn"

var _vm: TableScreenVM
var _frame: DesignFrame
var _room: TableRoom
var _cards: TableCards
var _hud: TableHud
var _choose: ChoosePanel
var _stake: StakePanel
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
	_deal = UiKit.button("Deal", true, 20)
	_deal.position = Vector2(TableHud.GUTTER, 324.0)
	_deal.custom_minimum_size = Vector2(280.0, 52.0)
	_deal.pressed.connect(_on_deal)
	_frame.add_child(_deal)


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
	if staking:
		_stake.refresh(_vm)
		_deal.text = "Deal   %s" % MoneyFormat.format(_vm.stake().total())
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


func _on_debug() -> void:
	get_tree().change_scene_to_file(DEBUG_SCENE)
