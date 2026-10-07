class_name ActionsFixture
extends RefCounted
## Builds rounds and their HandActions for the action suites. The owned deck
## holds exactly the given cards and the pile deals them in that order, so
## card i has id i. Each round deals from deck.dealing_cards(layer), as a
## table would, so changes on the layer show in the next hand. Actions are
## priced at the spec's center costs, at the tier set in tier.

const BET: int = 1000
## Wide table limits, so the ratio limits (spec §1.3) are the ones that bind.
const TABLE_MIN: int = 100
const TABLE_MAX: int = 100000

var config: TuneConfig = TuneConfig.load_default()
var deck: Deck
var layer: ManipulationLayer = ManipulationLayer.new()
var kit: ActionKit = ActionKit.everything()
var session: ActionSession = ActionSession.new()
## The opening bet of each round built.
var bet: int = BET
var heat_rules: HeatRules = HeatRules.from_config(config)
## The table's tier when the hand starts.
var tier: HeatTier.Kind = HeatTier.Kind.CLEAN
## Placed on each round built, before its deal.
var side_bets: Array[SideBet] = []
## The round built last.
var last_round: GameRound

var _build_edits: int = 0


func build_deck(codes: Array[String]) -> void:
	deck = Deck.new(0)
	for code: String in codes:
		var card: Card = Card.parse(code)
		deck.add_card(card.rank, card.suit)
	_build_edits = deck.edits().size()


## Deck edits made since build_deck(), which records its cards as additions.
func new_edits() -> Array[DeckEdit]:
	return deck.edits().slice(_build_edits)


func limits() -> BetLimits:
	return BetLimits.from_config(config, bet, TABLE_MIN, TABLE_MAX)


## A blackjack round on codes, dealt: in the hole-card window.
func blackjack(codes: Array[String]) -> BlackjackRound:
	build_deck(codes)
	return next_blackjack()


## Another blackjack hand from the same deck and layer.
func next_blackjack() -> BlackjackRound:
	var rules: BlackjackRules = BlackjackRules.from_config(config)
	var rnd: BlackjackRound = BlackjackRound.new(rules, limits(), deck.dealing_cards(layer))
	_place(rnd)
	rnd.deal()
	return rnd


## A baccarat round on codes, dealt: in the initial window.
func baccarat(codes: Array[String]) -> BaccaratRound:
	build_deck(codes)
	var rules: BaccaratRules = BaccaratRules.from_config(config)
	var pile: Array[Card] = deck.dealing_cards(layer)
	var rnd: BaccaratRound = BaccaratRound.new(rules, BaccaratRound.BetSide.PLAYER, limits(), pile)
	_place(rnd)
	rnd.deal()
	return rnd


## A High or Low round on codes, dealt: the first card up, in the first window.
func high_low(codes: Array[String]) -> HighLowRound:
	build_deck(codes)
	return next_high_low()


## Another High or Low round from the same deck and layer.
func next_high_low() -> HighLowRound:
	var rules: HighLowRules = HighLowRules.from_config(config)
	var rnd: HighLowRound = HighLowRound.new(rules, limits(), deck.cards(), deck.dealing_cards(layer))
	_place(rnd)
	rnd.deal()
	return rnd


func _place(rnd: GameRound) -> void:
	last_round = rnd
	rnd.place_side_bets(SideBetRules.from_config(config), side_bets)


## heat defaults to one priced at the center costs, at tier.
func actions(rnd: GameRound, heat: HandHeat = null) -> HandActions:
	if heat == null:
		var costs: TableCosts = TableCosts.centered(heat_rules, game_of(rnd))
		heat = HandHeat.new(heat_rules, costs, tier, session, kit)
	return HandActions.new(rnd, deck, layer, kit, session, heat)


static func game_of(rnd: GameRound) -> GameKind.Kind:
	if rnd is BaccaratRound:
		return GameKind.Kind.BACCARAT
	if rnd is HighLowRound:
		return GameKind.Kind.HIGH_LOW
	return GameKind.Kind.BLACKJACK


## Card ids, in order.
static func ids(cards: Array[Card]) -> Array[int]:
	var result: Array[int] = []
	for card: Card in cards:
		result.append(card.id)
	return result
