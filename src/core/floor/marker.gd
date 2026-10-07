class_name Marker
extends RefCounted
## The house's marker, one per run (spec §11): it fronts a shortfall up to
## max_share_pct of the quota, and the loan plus interest_pct joins the next
## floor's quota.


## What the house fronts toward quota from bankroll: the shortfall, capped.
static func front(config: TuneConfig, quota: int, bankroll: int) -> int:
	var cap: int = Money.apply_ratio(quota, config.get_int("marker", "max_share_pct"), 100)
	return clampi(quota - bankroll, 0, cap)


## The loan plus its interest.
static func owed(config: TuneConfig, loan: int) -> int:
	return loan + Money.apply_ratio(loan, config.get_int("marker", "interest_pct"), 100)
