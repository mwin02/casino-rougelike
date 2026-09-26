class_name MoneyFormat
extends RefCounted
## Dollar strings. Commas up to $999,999; above that one decimal of M or B,
## cut rather than rounded so the screen never overstates.

const MILLION: int = 1000000
const BILLION: int = 1000000000


static func format(amount: int) -> String:
	var sign: String = "-" if amount < 0 else ""
	var value: int = absi(amount)
	if value >= BILLION:
		return sign + "$" + _short(value, BILLION) + "B"
	if value >= MILLION:
		return sign + "$" + _short(value, MILLION) + "M"
	return sign + "$" + _commas(value)


## Like format, with a leading + on gains.
static func format_signed(amount: int) -> String:
	return ("+" if amount > 0 else "") + format(amount)


static func _short(value: int, unit: int) -> String:
	var tenths: int = value * 10 / unit
	var whole: int = tenths / 10
	var fraction: int = tenths % 10
	return str(whole) if fraction == 0 else "%d.%d" % [whole, fraction]


static func _commas(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return digits + out
