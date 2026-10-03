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
## Splits stop once the player holds this many hands.
var max_split_hands: int
## Insurance is at most this percent of the opening bet, and pays
## insurance_payout_num : insurance_payout_den on a dealer natural.
var insurance_max_pct: int
var insurance_payout_num: int
var insurance_payout_den: int


static func from_config(config: TuneConfig) -> BlackjackRules:
	var rules: BlackjackRules = BlackjackRules.new()
	rules.bust_threshold = config.get_int(SECTION, "bust_threshold")
	rules.natural_payout_num = config.get_int(SECTION, "natural_payout_num")
	rules.natural_payout_den = config.get_int(SECTION, "natural_payout_den")
	rules.dealer_stand = config.get_int(SECTION, "dealer_stand")
	rules.dealer_hits_soft_17 = config.get_bool(SECTION, "dealer_hits_soft_17")
	rules.max_split_hands = config.get_int(SECTION, "max_split_hands")
	rules.insurance_max_pct = config.get_int(SECTION, "insurance_max_pct")
	rules.insurance_payout_num = config.get_int(SECTION, "insurance_payout_num")
	rules.insurance_payout_den = config.get_int(SECTION, "insurance_payout_den")
	return rules


## The best total a hand can hold without busting.
func max_total() -> int:
	return bust_threshold - 1


## The dealer hits under the stand point, and on a soft stand point when the
## house hits soft 17.
func dealer_hits(dealer: BlackjackHand) -> bool:
	return dealer_hits_total(dealer.total(), dealer.is_soft())


func dealer_hits_total(total: int, soft: bool) -> bool:
	if total < dealer_stand:
		return true
	return total == dealer_stand and soft and dealer_hits_soft_17
