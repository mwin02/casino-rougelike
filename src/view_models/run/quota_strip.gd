class_name QuotaStrip
extends RefCounted
## How the floor's quota check went, as the end shop shows it (spec §6.2,
## §11).

## "FLOOR 1 · QUOTA CHECK".
var heading: String
## "Quota met", or "Short, marker covered it".
var title: String
## True when the marker covered the check.
var short: bool
## The bankroll at the check, before any money the marker fronted.
var bankroll_text: String
## "/ $140,000".
var quota_text: String
## The line under the check, its opening words: "Passed", or "Marker:
## house fronted $11,500".
var lead: String
## The rest of that line.
var detail: String
