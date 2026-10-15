class_name ServicePreview
extends RefCounted
## The deck service in progress, as the screen words it: what to do next,
## the card picked and what it becomes, the heat floor before and after
## (spec §4.2), and the button that pays for it.

## "Touch-up: pick a card".
var title: String = ""
var hint: String = ""
## The card picked; null with none.
var before: CardView
## What the change makes of it, or the card to add; null until chosen.
var after: CardView
## Whole, as every heat number on screen is.
var floor_before_text: String = ""
var floor_after_text: String = ""
## "Reforge".
var confirm_label: String = ""
var price_text: String = ""
var can_confirm: bool = false
## "BANKROLL $88,100 · $51,900 SHORT", after paying.
var after_text: String = ""
