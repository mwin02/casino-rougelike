class_name PartialQuestion
extends RefCounted
## The yes/no questions a partial reveal can ask (spec §2.5). Each game offers
## its own list; answers go by the card as it reads now.

enum Kind {
	## Blackjack, incoming card only: would it bust the active hand?
	BUSTS_ME,
	## Blackjack: 10, J, Q or K.
	TEN_CARD,
	## Blackjack, High or Low: hearts or diamonds.
	RED,
	## Baccarat: worth HIGH_FROM points or more.
	HIGH,
	## Baccarat: J, Q or K.
	FACE_CARD,
	## High or Low: within WITHIN_RANKS ranks of the card up, a tie included.
	WITHIN_THREE,
}

## Baccarat's "high" starts at this point value, so 5–9 is high.
const HIGH_FROM: int = 5
const WITHIN_RANKS: int = 3


static func is_red(card: Card) -> bool:
	return card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS


static func is_ten_card(card: Card) -> bool:
	return card.rank >= 10


static func is_face_card(card: Card) -> bool:
	return card.rank >= 11


static func is_baccarat_high(card: Card) -> bool:
	return BaccaratHand.value(card) >= HIGH_FROM


static func is_within_three(card: Card, up: Card) -> bool:
	return absi(card.rank - up.rank) <= WITHIN_RANKS
