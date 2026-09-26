class_name BlackjackRules
extends RefCounted
## Blackjack house rules (spec §3.1). Floor signatures change these per floor.

const SECTION: String = "blackjack"

## A hand at or above this total is bust.
var bust_threshold: int
## A natural pays natural_payout_num : natural_payout_den.
var natural_payout_num: int
var natural_payout_den: int
## The dealer stands on this total or more (hard), and on anything above it.
var dealer_stand: int
## If true, the dealer also hits a soft total equal to dealer_stand.
var dealer_hits_soft_17: bool


static func from_config(config: TuneConfig) -> BlackjackRules:
	var rules: BlackjackRules = BlackjackRules.new()
	rules.bust_threshold = config.get_int(SECTION, "bust_threshold")
	rules.natural_payout_num = config.get_int(SECTION, "natural_payout_num")
	rules.natural_payout_den = config.get_int(SECTION, "natural_payout_den")
	rules.dealer_stand = config.get_int(SECTION, "dealer_stand")
	rules.dealer_hits_soft_17 = config.get_bool(SECTION, "dealer_hits_soft_17")
	return rules


## The best total a hand can hold without busting.
func max_total() -> int:
	return bust_threshold - 1
