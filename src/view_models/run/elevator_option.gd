class_name ElevatorOption
extends RefCounted
## One door of the elevator (spec §5.3): the floor behind it, under its
## signature.

## "LEFT DOOR · FLOOR 2".
var door: String
## "Watchful pit".
var name: String
## The signature's pressure in a line.
var plain: String
## The floor's quota, marker debt included.
var quota_text: String
## "$560,000 + $14,375 marker (loan + 25%)". Empty with no debt.
var marker_text: String = ""
## "LOW $4,000–$16,000 · HIGH $20,000–$80,000".
var stakes_text: String
## "63 hands".
var hands_text: String
## "60 + 3 extra", or "15 fewer". Empty for the plain clock.
var clock_note: String = ""
## True when the signature shortens the clock.
var short_clock: bool = false
## "Ride to Watchful pit".
var ride_text: String
