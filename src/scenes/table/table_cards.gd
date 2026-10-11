class_name TableCards
extends Control
## Lays a hand's card groups out on the felt, to the design canvas: where
## each group sits, how its cards fan, and its total in a badge.

const DEALER_WIDTH: float = 52.0
const HAND_WIDTH: float = 60.0
const CENTRE_X: float = 422.0
## The width one blackjack hand takes when there are several.
const HAND_SLOT: float = 170.0
const TILTS: Array[float] = [-4.0, 3.0]
const SIDE_WIDTH: float = 52.0
## Where baccarat's player side ends and its banker side begins.
const SIDE_GAP_LEFT: float = 396.0
const SIDE_GAP_RIGHT: float = 448.0
const CHAIN_WIDTH: float = 68.0
const PAST_WIDTH: float = 40.0
## High or Low shows this many of the chain's earlier cards.
const PAST_SHOWN: int = 3


## box is the felt's centre box, as GameTableVM.felt_box() gives it.
func show_groups(groups: Array[CardGroup], box: PackedStringArray) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var banker: bool = false
	for group: CardGroup in groups:
		banker = banker or group.role == CardGroup.Role.BANKER
	var hands: Array[CardGroup] = []
	for group: CardGroup in groups:
		match group.role:
			CardGroup.Role.DEALER:
				_dealer(group)
			CardGroup.Role.PLAYER:
				if banker:
					_side(group, SIDE_GAP_LEFT, true)
				else:
					hands.append(group)
			CardGroup.Role.BANKER:
				_side(group, SIDE_GAP_RIGHT, false)
			CardGroup.Role.CHAIN_PAST:
				_past(group)
			CardGroup.Role.CARD_UP:
				_single(group, 368.0, Palette.GOLD)
			CardGroup.Role.NEXT_CARD:
				_single(group, 452.0, Palette.GOLD)
	for i: int in hands.size():
		_hand(hands[i], i, hands.size())
	if box.size() == 3:
		_box(box)


## A baccarat side: its cards from the centre gap outward (the player's to
## the left, the banker's to the right), its name under them with its total.
func _side(group: CardGroup, edge: float, leftward: bool) -> void:
	var count: int = group.cards.size()
	var step: float = SIDE_WIDTH + 6.0 if count <= 2 else 40.0
	var width: float = SIDE_WIDTH + (count - 1) * step
	var x: float = edge - width if leftward else edge
	for i: int in count:
		_card(group.cards[i], SIDE_WIDTH, Vector2(x + i * step, 112.0), 0.0)
	var name: Label = _felt_text(group.label.to_upper(), 14, 0.8)
	name.position = Vector2(x, 190.0)
	add_child(name)
	_badge(group.total_text, Vector2(x + 62.0, 186.0))


## High or Low's earlier cards, small and dimmed, the latest nearest the
## card up.
func _past(group: CardGroup) -> void:
	var shown: Array[CardView] = group.cards.slice(-PAST_SHOWN)
	var x: float = 344.0 - shown.size() * (PAST_WIDTH + 8.0) + 8.0
	for view: CardView in shown:
		_card(view, PAST_WIDTH, Vector2(x, 136.0), 0.0)
		x += PAST_WIDTH + 8.0


## One large card with its name under it: the card up, or the next card.
func _single(group: CardGroup, x: float, ink: Color) -> void:
	if group.cards.is_empty():
		return
	_card(group.cards[0], CHAIN_WIDTH, Vector2(x, 110.0), 0.0)
	var name: Label = _felt_text(group.label.to_upper(), 11, 1.0)
	name.add_theme_color_override("font_color", ink)
	name.position = Vector2(x - 6.0, 208.0)
	name.custom_minimum_size.x = CHAIN_WIDTH + 12.0
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name)


## The outlined box in the felt's centre: a caption, a headline, a footnote.
func _box(lines: PackedStringArray) -> void:
	var frame: PanelContainer = PanelContainer.new()
	var outline: StyleBoxFlat = UiKit.filled(Color.TRANSPARENT, 20)
	outline.draw_center = false
	outline.set_border_width_all(2)
	outline.border_color = Color(Palette.GOLD, 0.45)
	frame.add_theme_stylebox_override("panel", outline)
	frame.position = Vector2(300.0, 236.0)
	frame.custom_minimum_size = Vector2(244.0, 84.0)
	add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -4)
	frame.add_child(column)
	var caption: Label = _felt_text(lines[0], 11, 0.8)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	column.add_child(UiKit.label(lines[1], Fonts.Face.NUMBER, 34, Palette.CREAM))
	column.add_child(UiKit.label(lines[2], Fonts.Face.LABEL, 12, Palette.SOFT))


## Text printed on the felt: gold, condensed, part see-through.
func _felt_text(text: String, font_size: int, alpha: float) -> Label:
	var printed: Label = UiKit.label(text, Fonts.Face.NUMBER, font_size, Color(Palette.GOLD, alpha))
	printed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return printed


## The dealer's cards in a row under the silhouette, total beside them.
func _dealer(group: CardGroup) -> void:
	var gap: float = 6.0
	var count: int = group.cards.size()
	var x: float = CENTRE_X - (count * DEALER_WIDTH + (count - 1) * gap) / 2.0
	# A long hand's total moves to the left, clear of the panel on the right.
	var badge_x: float = x + count * (DEALER_WIDTH + gap) + 4.0 if count <= 2 else x - 42.0
	for view: CardView in group.cards:
		_card(view, DEALER_WIDTH, Vector2(x, 106.0), 0.0)
		x += DEALER_WIDTH + gap
	_badge(group.total_text, Vector2(badge_x, 128.0))


## A player hand: two cards side by side, more fanned, total to the left.
func _hand(group: CardGroup, index: int, count: int) -> void:
	var cards: int = group.cards.size()
	var step: float = HAND_WIDTH + 2.0 if cards <= 2 and count == 1 else 24.0
	var width: float = HAND_WIDTH + (cards - 1) * step
	var middle: float = CENTRE_X - 18.0 + (index - (count - 1) / 2.0) * HAND_SLOT
	var x: float = middle - width / 2.0 + 16.0
	_badge(group.total_text, Vector2(x - 54.0, 266.0))
	for i: int in cards:
		_card(group.cards[i], HAND_WIDTH, Vector2(x + i * step, 240.0), TILTS[i % 2])


func _card(view: CardView, width: float, at: Vector2, tilt: float) -> void:
	var face: CardFace = CardFace.new()
	add_child(face)
	face.position = at
	face.show_card(view, width)
	face.pivot_offset = face.size / 2.0
	face.rotation_degrees = tilt


func _badge(text: String, at: Vector2) -> void:
	if text.is_empty():
		return
	var badge: Label = UiKit.label(text, Fonts.Face.NUMBER, 17, Palette.CREAM)
	var box: StyleBoxFlat = UiKit.filled(Palette.PANEL, 15)
	box.set_border_width_all(2)
	box.border_color = Palette.GOLD
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	badge.add_theme_stylebox_override("normal", box)
	badge.position = at
	add_child(badge)
