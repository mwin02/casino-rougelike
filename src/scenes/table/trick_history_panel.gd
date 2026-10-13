class_name TrickHistoryPanel
extends PanelContainer
## The Tricks screen's left panel: what the actions found or did this hand,
## newest first, with the cards a look ahead showed. A change that can still
## be kept has its Tape, Seal and Ink under its row, each with how many are
## left. Hidden until there's something to show.

signal changed

const WIDTH: float = 164.0

var _vm: TableScreenVM
var _body: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = UiKit.panel_column(self, 8, 4)
	var title: Label = UiKit.label("THIS HAND", Fonts.Face.LABEL, 11, Palette.MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)


## max_height is the room the panel has; past it, its rows scroll.
func refresh(vm: TableScreenVM, max_height: float) -> void:
	_vm = vm
	var picker: ActionPicker = vm.picker()
	var rows: Array[TrickRow] = []
	if picker != null and vm.in_hand():
		rows = picker.history()
	visible = not rows.is_empty()
	if rows.is_empty():
		return
	UiKit.clear(_body)
	if not picker.shown_cards.is_empty():
		_body.add_child(_shown(picker.shown_cards))
	for row: TrickRow in rows:
		var told: Label = UiKit.label(row.text, Fonts.Face.BODY_HEAVY, 11, Palette.TEAL)
		told.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		told.custom_minimum_size.x = WIDTH - 20.0
		_body.add_child(told)
		if not row.keeps.is_empty():
			_body.add_child(_keeps(row))
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, max_height - 40.0)
	reset_size()


## The cards a look ahead showed, in order off the deck.
func _shown(shown: Array[Card]) -> HBoxContainer:
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 5)
	for card: Card in shown:
		var face: CardFace = CardFace.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cards.add_child(face)
		face.show_card(CardView.new(card, false, false), 30.0)
	return cards


## Tape, Seal and Ink for a row's change, side by side.
func _keeps(row: TrickRow) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	for keep: Choice in row.keeps:
		var button: Button = UiKit.option("%s %s" % [keep.label, keep.detail], false, 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34.0
		button.disabled = not keep.enabled
		# A drag that starts on a button still scrolls the list.
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(_keep.bind(keep.id))
		line.add_child(button)
	return line


func _keep(id: int) -> void:
	_vm.picker().keep(id)
	changed.emit()
