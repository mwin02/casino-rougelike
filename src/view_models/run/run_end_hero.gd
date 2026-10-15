class_name RunEndHero
extends RefCounted
## The run end's headline (spec §11): how the run ended and its score.

## "RUN OVER · FLOOR 3".
var kicker: String
## "Ejected."
var title: String
var sub: String
## "FINAL SCORE", or what the bankroll is when the run was lost.
var score_label: String
var score_text: String
## "$25,000 per heat" over the whole run, for a won one; else empty.
var per_heat_text: String = ""
## "Started with $50,000. Reached floor 3 of 5."
var footnote: String
