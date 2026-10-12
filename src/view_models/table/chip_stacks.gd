class_name ChipStacks
extends RefCounted
## How a sum of money is shown in chips, the same everywhere on the table.
## Chips come in denominations ten times apart, from $100 up: $100, $1,000,
## $10,000 and so on, past the largest quota. A sum shows as one stack per
## denomination, at most its two largest, so it never takes more than two
## stacks of nine: anything smaller than a chip of the second stack is
## rounded to the nearest one. $4,340 shows as four $1,000 chips and three
## $100 chips; $1,260,000 as one $1,000,000 chip and three $100,000 chips.

const SMALLEST: int = 100
const STEP: int = 10
## $100 up to $1,000,000,000.
const DENOMINATIONS: int = 8


class Stack:
	extends RefCounted
	## 0 for the smallest chip, 1 for the next, and so on.
	var denomination: int
	var count: int

	func _init(p_denomination: int, p_count: int) -> void:
		denomination = p_denomination
		count = p_count

	## What the stack is worth.
	func dollars() -> int:
		return ChipStacks.value(denomination) * count


## What one chip of denomination is worth.
static func value(denomination: int) -> int:
	var dollars: int = SMALLEST
	for i: int in denomination:
		dollars *= STEP
	return dollars


## amount as stacks, the largest denomination first. Nothing for a sum too
## small to round up to one chip.
static func of(amount: int) -> Array[Stack]:
	var stacks: Array[Stack] = []
	var rounded: int = _rounded(amount)
	if rounded <= 0:
		return stacks
	var top: int = _top(rounded)
	stacks.append(Stack.new(top, rounded / value(top)))
	var rest: int = rounded % value(top)
	if top > 0 and rest > 0:
		stacks.append(Stack.new(top - 1, rest / value(top - 1)))
	return stacks


## The dollars the stacks of amount add up to: amount, rounded.
static func shown(amount: int) -> int:
	var sum: int = 0
	for stack: Stack in of(amount):
		sum += stack.dollars()
	return sum


## The largest denomination no bigger than amount.
static func _top(amount: int) -> int:
	var top: int = 0
	while top < DENOMINATIONS - 1 and value(top + 1) <= amount:
		top += 1
	return top


## amount to the nearest chip of the denomination under its largest.
static func _rounded(amount: int) -> int:
	if amount <= 0:
		return 0
	var unit: int = value(maxi(_top(amount) - 1, 0))
	return (amount + unit / 2) / unit * unit
