---
name: godot-testing
description: How to write and run GdUnit4 tests in this Godot project. Load when writing, fixing, or running tests, or when turning a visual bug into a test.
---

# Testing in this project

## Running
- `scripts/check` runs lint and the full suite. This is what the Stop hook runs.
- `scripts/test` runs the suite only. `scripts/test res://test/core/blackjack` runs one directory, and `scripts/test res://test/core/blackjack/hand_test.gd` runs one suite.
- `scripts/test` first compiles every script under `src/ test/ sim/ scripts/`, so a typed-warning error anywhere fails the run even if no test loads that file.
- Reports are written to `reports/` (gitignored).

## Layout and naming
- `test/` mirrors `src/`: `src/core/blackjack/hand.gd` is tested by `test/core/blackjack/hand_test.gd`. Suites must end in `_test.gd`.
- A suite `extends GdUnitTestSuite`. Test functions are `func test_<behaviour>() -> void:`, named for the rule, e.g. `test_dealer_hits_soft_17`.
- Scenes are not unit-tested. Test the core and view models.
- Tests are typed like all other code: `var hand: Hand = Hand.new()`.

## Asserts (common)
`assert_int(x).is_equal(3)`, `assert_bool(b).is_true()`, `assert_str(s).is_equal("...")`, `assert_float(f).is_equal_approx(1.5, 0.0001)`, `assert_array(a).contains_exactly([...])`, `assert_that(obj).is_equal(other)`.

## Deterministic randomness
- Core code never calls global `randi()` / `randf()`. It takes a `RandomNumberGenerator` (or a project RNG wrapper once Block 1 adds one) through the constructor or as a parameter.
- In tests, build it with a fixed seed:
  ```gdscript
  var rng: RandomNumberGenerator = RandomNumberGenerator.new()
  rng.seed = 12345
  ```
- For "same seed gives the same result", run twice with fresh RNGs on the same seed and compare. For "different seeds differ", pick two seeds and assert on the specific results you observed.
- Prefer building exact cards or decks over fishing for a seed. Use a seed only when the shuffle itself is under test.

## Table-driven tests
Use GdUnit4 parameterized tests for rule tables (third-card rules, payouts, hand totals):
```gdscript
func test_hand_total(cards: Array, expected: int, test_parameters: Array = [
	[["A", "K"], 21],
	[["A", "A", "9"], 21],
]) -> void:
	...
```

## Config values
Tests read `[TUNE]` values from config rather than repeating the literal, unless the test pins a specific spec number on purpose (then cite the spec section in a comment).

## Turning a visual bug into a test
1. Identify what the screen drew wrongly: a label, a button state, a number, a list.
2. Find the view-model field or method the scene reads for it. If the scene computes it itself, that is the bug: move the logic into the view model.
3. Write a failing test on the view model (or the core, if the wrong value comes from the rules) that reproduces the exact state. Assert on data, never on nodes.
4. Fix the code, and watch the test pass.
