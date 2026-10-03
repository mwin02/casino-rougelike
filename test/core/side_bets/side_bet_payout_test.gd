extends GdUnitTestSuite
## Each side bet's tiers (spec §8), read from config.

const LOSE: int = SideBetPayout.LOSE
const PUSH: int = SideBetPayout.PUSH
const PLAYER: BaccaratRound.BetSide = BaccaratRound.BetSide.PLAYER
const BANKER: BaccaratRound.BetSide = BaccaratRound.BetSide.BANKER

var _config: TuneConfig = TuneConfig.load_default()
var _rules: SideBetRules = SideBetRules.from_config(_config)


func _c(code: String) -> Card:
	return Card.parse(code)


func _dealer(codes: Array) -> BlackjackHand:
	var hand: BlackjackHand = BlackjackHand.new(BlackjackRules.from_config(_config))
	for code: String in codes:
		hand.add(_c(code))
	return hand


func test_each_kind_belongs_to_its_game() -> void:
	var kinds: Array[SideBetKind.Kind] = SideBetKind.for_game(GameKind.Kind.BLACKJACK)
	assert_array(kinds).contains_exactly([
		SideBetKind.Kind.PERFECT_PAIRS,
		SideBetKind.Kind.TWENTY_ONE_PLUS_THREE,
		SideBetKind.Kind.BUST_IT,
	])
	kinds = SideBetKind.for_game(GameKind.Kind.BACCARAT)
	assert_array(kinds).contains_exactly([SideBetKind.Kind.DRAGON_BONUS, SideBetKind.Kind.PAIR])
	kinds = SideBetKind.for_game(GameKind.Kind.HIGH_LOW)
	assert_array(kinds).contains_exactly([SideBetKind.Kind.EXACT_RANK])


func test_cap_is_a_share_of_table_max() -> void:
	# Spec §8: 25% of table max; Side Pocket (§9) passes 50.
	assert_int(_rules.cap(20000)).is_equal(5000)
	assert_int(_rules.cap(20000, 50)).is_equal(10000)


func test_net_pays_n_to_1() -> void:
	assert_int(SideBetPayout.net(100, LOSE)).is_equal(-100)
	assert_int(SideBetPayout.net(100, PUSH)).is_equal(0)
	assert_int(SideBetPayout.net(100, 24)).is_equal(2400)


# gdlint: ignore=unused-argument
func test_perfect_pairs(a: String, b: String, tier: int, test_parameters: Array = [
	["7H", "7D", 1],  # both red: coloured
	["7S", "7C", 1],
	["7H", "7S", 0],  # mixed
	["7H", "8H", -1],
	["KH", "QH", -1],  # ten-values aren't a pair
]) -> void:
	var expected: int = LOSE if tier < 0 else _rules.perfect_pairs[tier]
	assert_int(SideBetPayout.perfect_pairs(_rules, _c(a), _c(b))).is_equal(expected)


# gdlint: ignore=unused-argument
func test_twenty_one_plus_three(codes: Array, tier: int, test_parameters: Array = [
	[["5H", "6H", "7H"], 0],  # straight flush
	[["AS", "2S", "3S"], 0],
	[["QD", "KD", "AD"], 0],
	[["9H", "9S", "9C"], 1],  # three of a kind
	[["AH", "2S", "3C"], 2],  # straight, ace low
	[["QH", "KS", "AC"], 2],  # straight, ace high
	[["KH", "AS", "2C"], -1],  # no wrap round the corner
	[["2H", "9H", "KH"], 3],  # flush
	[["2H", "9H", "KS"], -1],
]) -> void:
	var expected: int = LOSE if tier < 0 else _rules.twenty_one_plus_three[tier]
	var cards: Array[Card] = []
	for code: String in codes:
		cards.append(_c(code))
	var pays: int = SideBetPayout.twenty_one_plus_three(_rules, cards[0], cards[1], cards[2])
	assert_int(pays).is_equal(expected)


# gdlint: ignore=unused-argument
func test_bust_it(codes: Array, tier: int, test_parameters: Array = [
	[["10", "6", "K"], 0],
	[["2", "4", "10", "K"], 1],
	[["2", "3", "A", "6", "Q"], 2],  # A counts 1 once it would bust
	[["2", "2", "2", "3", "5", "K"], 3],
	[["A", "A", "2", "2", "3", "3", "K"], 4],
	[["A", "A", "A", "2", "2", "2", "3", "K"], 4],  # 7 or more cards
	[["10", "7"], -1],
	[["A", "K"], -1],
]) -> void:
	var expected: int = LOSE if tier < 0 else _rules.bust_it[tier]
	assert_int(SideBetPayout.bust_it(_rules, _dealer(codes))).is_equal(expected)


# gdlint: ignore=unused-argument
func test_dragon_bonus(pt: int, bt: int, nat: bool, on_p: int, on_b: int, test_parameters: Array = [
	# player total, banker total, natural, then the tier on Player and on Banker
	[9, 0, false, 5, -1],  # tier 5: win by 9
	[7, 3, false, 0, -1],  # tier 0: win by 4
	[6, 3, false, -1, -1],  # win by 3 loses
	[8, 1, true, -2, -1],  # -2: the natural win
	[7, 9, true, -1, -2],
	[8, 8, true, -3, -3],  # -3: a natural tie pushes
	[5, 5, false, -1, -1],  # other ties lose
]) -> void:
	assert_int(SideBetPayout.dragon_bonus(_rules, PLAYER, pt, bt, nat)).is_equal(_dragon(on_p))
	assert_int(SideBetPayout.dragon_bonus(_rules, BANKER, pt, bt, nat)).is_equal(_dragon(on_b))


func _dragon(code: int) -> int:
	match code:
		-1:
			return LOSE
		-2:
			return _rules.dragon_natural
		-3:
			return PUSH
	return _rules.dragon_bonus[code]


func test_pair_needs_same_rank_only() -> void:
	assert_int(SideBetPayout.pair(_rules, _c("4H"), _c("4S"))).is_equal(_rules.pair)
	assert_int(SideBetPayout.pair(_rules, _c("JH"), _c("QH"))).is_equal(LOSE)


func test_exact_rank() -> void:
	assert_int(SideBetPayout.exact_rank(_rules, 12, _c("QD"))).is_equal(_rules.exact_rank)
	assert_int(SideBetPayout.exact_rank(_rules, 12, _c("KD"))).is_equal(LOSE)
