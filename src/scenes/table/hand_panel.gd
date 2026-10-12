class_name HandPanel
extends PanelContainer
## The panel beside a hand in play, to the design canvas. In a window it
## says what the window is about and offers the eye in the sky; at any time
## it holds the game's own buttons (Hit, Stand, a High or Low call...).

signal played(id: int)
signal eye_wanted

const WIDTH: float = 214.0
## A label longer than this takes a full row of the button grid.
const WIDE_LABEL: int = 12

var _title: Label
var _tag: Label
var _note: Label
var _eye: Button
var _plays: GridContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var column: VBoxContainer = UiKit.panel_column(self, 12, 8)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	_title = UiKit.label("", Fonts.Face.TITLE, 17, Palette.CREAM)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(_title)
	_tag = UiKit.chip("", Palette.GOLD, Palette.PANEL, 11)
	head.add_child(_tag)
	_note = UiKit.label("", Fonts.Face.BODY, 12, Palette.SOFT)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label needs its width up front, or it asks for a tall panel.
	_note.custom_minimum_size.x = WIDTH - 24.0
	column.add_child(_note)
	_eye = UiKit.button("", true, 13)
	_eye.custom_minimum_size.y = 54.0
	_eye.pressed.connect(eye_wanted.emit)
	column.add_child(_eye)
	_plays = GridContainer.new()
	_plays.add_theme_constant_override("h_separation", 6)
	_plays.add_theme_constant_override("v_separation", 6)
	column.add_child(_plays)


func refresh(vm: TableScreenVM) -> void:
	var game: GameTableVM = vm.game()
	if game == null or not vm.in_hand():
		return
	var window: bool = vm.stage() == TableScreenVM.Stage.WINDOW
	_title.text = "Window open" if window else game.phase_text()
	_tag.text = vm.window_tag()
	_tag.visible = window
	_note.text = vm.window_note()
	_note.visible = window
	_eye.text = "Eye in the sky\n" + vm.eye_text()
	_eye.visible = window
	var choices: Array[Choice] = game.shown_choices()
	var wide: bool = false
	for choice: Choice in choices:
		wide = wide or choice.label.length() > WIDE_LABEL
	_plays.columns = 1 if wide else 2
	_plays.visible = not choices.is_empty()
	UiKit.clear(_plays)
	for choice: Choice in choices:
		var button: Button = UiKit.option(choice.label, false, 15)
		button.custom_minimum_size.y = 44.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not choice.enabled
		button.pressed.connect(played.emit.bind(choice.id))
		_plays.add_child(button)
	reset_size()
