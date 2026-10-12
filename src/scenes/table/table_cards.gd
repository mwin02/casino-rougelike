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


func show_groups(groups: Array[CardGroup]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var hands: Array[CardGroup] = []
	for group: CardGroup in groups:
		if group.role == CardGroup.Role.DEALER:
			_dealer(group)
		elif group.role == CardGroup.Role.PLAYER:
			hands.append(group)
	for i: int in hands.size():
		_hand(hands[i], i, hands.size())


## The dealer's cards in a row under the silhouette, total to the right.
func _dealer(group: CardGroup) -> void:
	var gap: float = 6.0
	var count: int = group.cards.size()
	var x: float = CENTRE_X - (count * DEALER_WIDTH + (count - 1) * gap) / 2.0
	for view: CardView in group.cards:
		_card(view, DEALER_WIDTH, Vector2(x, 106.0), 0.0)
		x += DEALER_WIDTH + gap
	_badge(group.total_text, Vector2(x + 4.0, 128.0))


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
