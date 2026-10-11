extends GdUnitTestSuite
## A floor signature may name a house rule for every table on its floor
## (spec §5.3). The boss floor's rule is [OPEN]: its hook in config is empty,
## so floor 5 plays as the baseline until it is decided.

const BET: int = TableSessionFixture.BET
## Player 10 + 5 hits a 7 for 22; dealer 10 + 8.
const TWENTY_TWO: Array[String] = ["10", "10", "5", "8", "7"]

var _s: TableSessionFixture


func before_test() -> void:
	_s = TableSessionFixture.new()


## The default config with the boss floor's hook set to rule.
func _boss_config(rule: String) -> TuneConfig:
	var text: String = FileAccess.get_file_as_string(TuneConfig.DEFAULT_PATH)
	var old: String = 'boss_house_rule=""'
	assert_bool(text.contains(old)).is_true()
	return TuneConfig.parse(text.replace(old, 'boss_house_rule="%s"' % rule))


## Hits once at a blackjack table on a boss floor and returns the round.
func _hit_on_the_boss_floor(config: TuneConfig) -> BlackjackRound:
	_s.config = config
	_s.signature = FloorSignature.of(config, FloorSignature.Kind.BOSS)
	var session: TableSession = _s.sit(GameKind.Kind.BLACKJACK, TWENTY_TWO)
	session.start_hand(BET)
	var rnd: BlackjackRound = session.current_round()
	rnd.proceed()
	rnd.proceed()
	BlackjackRoundFixture.hit(rnd)
	return rnd


func test_the_boss_hook_is_empty_by_default() -> void:
	var config: TuneConfig = TuneConfig.load_default()
	assert_str(config.get_string("signatures", "boss_house_rule")).is_empty()
	assert_str(FloorSignature.of(config, FloorSignature.Kind.BOSS).house_rule).is_empty()
	assert_bool(_hit_on_the_boss_floor(config).active_hand().is_bust()).is_true()


func test_no_other_signature_names_a_rule() -> void:
	var config: TuneConfig = _boss_config("bust_23")
	for kind: FloorSignature.Kind in FloorSignature.POOL:
		assert_str(FloorSignature.of(config, kind).house_rule).is_empty()
	assert_str(FloorSignature.baseline().house_rule).is_empty()


func test_a_signatures_rule_applies_at_its_games_tables() -> void:
	var config: TuneConfig = _boss_config("bust_23")
	assert_array(config.problems()).is_empty()
	var rnd: BlackjackRound = _hit_on_the_boss_floor(config)
	assert_int(rnd.active_hand().total()).is_equal(22)
	assert_bool(rnd.active_hand().is_bust()).is_false()


func test_a_signatures_rule_leaves_other_games_alone() -> void:
	var config: TuneConfig = _boss_config("bust_23")
	var signature: FloorSignature = FloorSignature.of(config, FloorSignature.Kind.BOSS)
	assert_object(signature.rules_config(config, GameKind.Kind.BACCARAT)).is_same(config)
	assert_array(
		signature.rules_config(config, GameKind.Kind.BLACKJACK).applied_house_rules()
	).is_equal(["bust_23"])


func test_a_tables_own_rule_stacks_on_the_floors() -> void:
	var config: TuneConfig = _boss_config("bust_23")
	_s.house_rule = "no_side_bets"
	var rnd: BlackjackRound = _hit_on_the_boss_floor(config)
	assert_bool(rnd.active_hand().is_bust()).is_false()
	_s.signature = FloorSignature.of(config, FloorSignature.Kind.BOSS)
	assert_bool(_s.again(GameKind.Kind.BLACKJACK).side_bets_offered()).is_false()


func test_a_boss_hook_naming_no_rule_is_a_problem() -> void:
	var problems: PackedStringArray = _boss_config("no_such_rule").problems()
	assert_bool("signatures/boss_house_rule" in "\n".join(problems)).is_true()
