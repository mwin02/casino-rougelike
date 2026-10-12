class_name Palette
extends RefCounted
## The table screen's colours, from the design canvas ("Rob the Casino —
## game screens"). Presentation only: nothing here is a [TUNE] value.

const NIGHT: Color = Color("1E2538")
const WALL: Color = Color("27304A")
const PANEL: Color = Color("1B2233")
const PANEL_EDGE: Color = Color("0C111C")
const WELL: Color = Color("141A28")
const BUTTON: Color = Color("2C3650")
const OUTLINE: Color = Color("4A5578")
const CREAM: Color = Color("F3EAD6")
const CREAM_EDGE: Color = Color("CDBF9E")
const MUTED: Color = Color("A9ADBD")
const SOFT: Color = Color("C9CCD8")
const GOLD: Color = Color("D4AF5F")
const GOLD_EDGE: Color = Color("9C7F3C")
const FELT: Color = Color("2F5E4E")
const RAIL: Color = Color("4A2F22")
const RAIL_EDGE: Color = Color("2E1C14")
const CARD_BACK: Color = Color("7A2E2E")
const CARD_RED: Color = Color("B94A3A")
const CARD_BLACK: Color = Color("1B2233")
const TEAL: Color = Color("9FD3C7")
const WIN: Color = Color("6FA38A")
const LOSS: Color = Color("E07A62")
const TAPE: Color = Color("E3D3A4")
## The pen that writes on the tape.
const MARKER: Color = Color("23346B")
## A Cold Seal's wax.
const SEAL: Color = Color("8DB4DC")
## The edge of a card added to the deck.
const ADDED: Color = Color("3F8F86")
## One per heat tier (spec §7.1), Clean first.
const TIERS: Array[Color] = [
	Color("6FA38A"), Color("D4AF5F"), Color("E08A4A"), Color("C9473B"),
]
