class_name ServicesBench
extends PanelContainer
## The deck service in progress, to the "Back room · deck services"
## artboard: what to do next, the cards to pick from in suit rows, the
## picked card and what it becomes, the heat floor before and after, the
## change's ranks and suits, and the button that pays. Draws a ServicesVM
## and forwards presses; `changed` asks its screen to redraw.

signal changed

const SIZE: Vector2 = Vector2(508.0, 314.0)
const GRID_WIDTH: float = 336.0
const CARD_WIDTH: float = 24.0
const CARD_STEP: float = 26.0
const ROW_STEP: float = 38.0
## Spades, hearts, clubs, diamonds, top to bottom.
const SUIT_ROWS: Array[Card.Suit] = [
	Card.Suit.SPADES, Card.Suit.HEARTS, Card.Suit.CLUBS, Card.Suit.DIAMONDS,
]

var _vm: ServicesVM
var _title: Label
var _hint: Label
var _cancel: Button
var _grid: Control
var _before: CardFace
var _after: CardFace
var _arrow: TextureRect
var _floor: Label
var _ranks: HFlowContainer
var _suits: HBoxContainer
var _confirm: Button
var _after_text: Label


func _init(vm: ServicesVM) -> void:
	_vm = vm
	custom_minimum_size = SIZE
	size = SIZE
	var column: VBoxContainer = UiKit.panel_column(self, 9, 6)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	_title = _left(UiKit.label("", Fonts.Face.TITLE, 18, Palette.CREAM))
	words.add_child(_title)
	_hint = _left(UiKit.label("", Fonts.Face.BODY, 11, Palette.MUTED))
	_hint.clip_text = true
	words.add_child(_hint)
	_cancel = UiKit.button("Cancel", false, 14)
	_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cancel.pressed.connect(_on_cancel)
	head.add_child(_cancel)
	var middle: HBoxContainer = HBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	middle.custom_minimum_size.y = 150.0
	column.add_child(middle)
	_grid = Control.new()
	_grid.custom_minimum_size = Vector2(GRID_WIDTH, 150.0)
	middle.add_child(_grid)
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(side)
	side.add_child(_build_becomes())
	side.add_child(_build_floor())
	column.add_child(_build_change())


## PICKED → BECOMES: the card before and after.
func _build_becomes() -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.add_theme_stylebox_override("panel", ShopCards.inset())
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	box.add_child(column)
	column.add_child(ShopCards.heading("PICKED", "BECOMES"))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	_before = CardFace.new()
	row.add_child(_before)
	_arrow = Icons.rect("icons/arrow", 16.0, Palette.GOLD)
	row.add_child(_arrow)
	_after = CardFace.new()
	row.add_child(_after)
	return box


## The heat floor every table starts at, before → after.
func _build_floor() -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = ShopCards.inset()
	style.border_color = Color(Palette.GOLD, 0.35)
	box.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var name: Label = _left(UiKit.label("Heat floor", Fonts.Face.BUTTON, 12, Palette.CREAM))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	_floor = UiKit.label("", Fonts.Face.NUMBER, 16, Palette.GOLD)
	row.add_child(_floor)
	return box


## The change's ranks and suits, then the button that pays for it.
func _build_change() -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.add_theme_stylebox_override("panel", ShopCards.inset())
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var picks: VBoxContainer = VBoxContainer.new()
	picks.alignment = BoxContainer.ALIGNMENT_CENTER
	picks.add_theme_constant_override("separation", 4)
	picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picks)
	_ranks = HFlowContainer.new()
	_ranks.add_theme_constant_override("h_separation", 3)
	_ranks.add_theme_constant_override("v_separation", 3)
	picks.add_child(_ranks)
	_suits = HBoxContainer.new()
	_suits.add_theme_constant_override("separation", 4)
	picks.add_child(_suits)
	var pay: VBoxContainer = VBoxContainer.new()
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	pay.add_theme_constant_override("separation", 2)
	pay.custom_minimum_size.x = 176.0
	row.add_child(pay)
	_confirm = UiKit.button("", true, 15)
	_confirm.custom_minimum_size.y = 44.0
	_confirm.pressed.connect(_on_confirm)
	pay.add_child(_confirm)
	_after_text = UiKit.label("", Fonts.Face.LABEL, 10, Palette.MUTED)
	pay.add_child(_after_text)
	return box


func refresh() -> void:
	var view: ServicePreview = _vm.preview()
	var idle: bool = _vm.selected() == ServicesVM.NONE
	_title.text = view.title
	_hint.text = view.hint
	_cancel.visible = not idle
	_cancel.text = "Skip" if _vm.rummage_open() else "Cancel"
	_show_cards()
	_before.visible = view.before != null
	if view.before != null:
		_before.show_card(view.before, 36.0)
	_after.visible = view.after != null
	if view.after != null:
		_after.show_card(view.after, 36.0)
	_arrow.visible = view.before != null and view.after != null
	_floor.text = "%s → %s" % [view.floor_before_text, view.floor_after_text]
	_floor.visible = not idle
	UiKit.clear(_ranks)
	for choice: Choice in _vm.rank_options():
		var button: Button = _option(choice)
		button.pressed.connect(_on_rank.bind(choice.id))
		_ranks.add_child(button)
	UiKit.clear(_suits)
	for choice: Choice in _vm.suit_options():
		var button: Button = _option(choice)
		button.text = ""
		button.icon = CardFace.SUITS[choice.id]
		button.add_theme_constant_override("icon_max_width", 14)
		button.pressed.connect(_on_suit.bind(choice.id))
		_suits.add_child(button)
	_confirm.visible = not idle
	_confirm.text = ("%s  %s" % [view.confirm_label, view.price_text]).strip_edges()
	_confirm.disabled = not view.can_confirm
	_after_text.text = "" if idle else view.after_text


## A rank or suit as a small button, gold when chosen.
func _option(choice: Choice) -> Button:
	var button: Button = UiKit.option(choice.label, choice.selected, 12)
	button.custom_minimum_size = Vector2(22.0, 26.0)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state)
		box.content_margin_left = 5
		box.content_margin_right = 5
		box.content_margin_top = 2
		box.content_margin_bottom = 3
	return button


## The cards to pick from, a row per suit; a longer row closes up to fit.
func _show_cards() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var rows: Dictionary[Card.Suit, Array] = {}
	for view: CardView in _vm.cards():
		if not rows.has(view.suit):
			rows[view.suit] = []
		rows[view.suit].append(view)
	for r: int in SUIT_ROWS.size():
		var row: Array = rows.get(SUIT_ROWS[r], [])
		var step: float = CARD_STEP
		if row.size() > 1:
			step = minf(CARD_STEP, (GRID_WIDTH - CARD_WIDTH) / (row.size() - 1))
		for i: int in row.size():
			var view: CardView = row[i]
			_grid.add_child(_card(view, Vector2(step * i, ROW_STEP * r)))


## One card to tap, lifted and ringed in gold when it is the one picked.
func _card(view: CardView, at: Vector2) -> Control:
	var picked: bool = view.id == _vm.picked_id()
	var face: CardFace = CardFace.new()
	face.draws_mark = true
	face.show_card(view, CARD_WIDTH)
	face.position = at + (Vector2(0.0, -2.0) if picked else Vector2.ZERO)
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.gui_input.connect(_on_card_input.bind(view.id))
	if picked:
		var ring: Panel = Panel.new()
		var box: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 4)
		box.draw_center = false
		box.set_border_width_all(2)
		box.border_color = Palette.GOLD
		ring.add_theme_stylebox_override("panel", box)
		ring.position = Vector2(-2.0, -2.0)
		ring.size = face.size + Vector2(4.0, 4.0)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(ring)
	return face


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _on_card_input(event: InputEvent, id: int) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (touch != null and touch.pressed) or (click != null and click.pressed):
		_vm.pick_card(id)
		changed.emit()


func _on_rank(rank: int) -> void:
	_vm.choose_rank(rank)
	changed.emit()


func _on_suit(suit: int) -> void:
	_vm.choose_suit(suit)
	changed.emit()


func _on_cancel() -> void:
	_vm.cancel()
	changed.emit()


func _on_confirm() -> void:
	_vm.confirm()
	changed.emit()
