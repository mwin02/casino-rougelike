class_name Money
extends RefCounted
## Money is whole dollars. Every fractional result rounds down, in the
## house's favour, through here (spec §6.2).


## amount × num / den, rounded toward negative infinity.
static func apply_ratio(amount: int, num: int, den: int) -> int:
	var product: int = amount * num
	var quotient: int = product / den
	if product % den != 0 and (product < 0) != (den < 0):
		quotient -= 1
	return quotient
