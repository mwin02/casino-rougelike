class_name TableSessionFixture
extends RefCounted
## Builds table sessions for the session suites. The owned deck holds exactly
## the given cards and every hand deals them in that order, so card i has id i
## (StackedTableSession). The table is floor 1, $1,000–4,000.

const BET: int = 1000
const TABLE_MIN: int = 1000
const TABLE_MAX: int = 4000
const BANKROLL: int = 50000
const SEED: int = 777

var config: TuneConfig = TuneConfig.load_default()
var deck: Deck
var layer: ManipulationLayer = ManipulationLayer.new()
var kit: ActionKit = ActionKit.everything()
var rng: GameRng = GameRng.new(SEED)
## A floor clock for every session sat from here on, or null.
var clock: FloorClock


func build_deck(codes: Array[String]) -> void:
	deck = Deck.new(0)
	for code: String in codes:
		var card: Card = Card.parse(code)
		deck.add_card(card.rank, card.suit)


func table(game: GameKind.Kind) -> Table:
	return Table.new(game, TableStakes.Kind.LOW, 1, TABLE_MIN, TABLE_MAX)


## Sits down at a game on a deck of codes.
func sit(
	game: GameKind.Kind,
	codes: Array[String],
	bankroll: int = BANKROLL,
	heat_floor: float = 0.0
) -> TableSession:
	build_deck(codes)
	return again(game, bankroll, heat_floor)


## Sits down again on the same deck and layer.
func again(
	game: GameKind.Kind, bankroll: int = BANKROLL, heat_floor: float = 0.0
) -> TableSession:
	return StackedTableSession.new(
		config, table(game), deck, layer, kit, rng, bankroll, heat_floor, clock
	)


## Every card rank repeated count times, e.g. repeat("K", 6).
static func repeat(code: String, count: int) -> Array[String]:
	var codes: Array[String] = []
	for i: int in count:
		codes.append(code)
	return codes


## Passes every window and adjust until the round resolves. Blackjack stands
## each hand; High or Low calls higher and banks any win.
static func play_out(session: TableSession) -> void:
	var rnd: GameRound = session.current_round()
	var guard: int = 0
	while not rnd.is_resolved() and guard < 100:
		guard += 1
		if rnd is BlackjackRound:
			var bj: BlackjackRound = rnd
			if bj.phase == BlackjackRound.Phase.PLAYER_TURN:
				bj.stand()
			else:
				bj.proceed()
		elif rnd is BaccaratRound:
			var bac: BaccaratRound = rnd
			bac.proceed()
		elif rnd is HighLowRound:
			var hl: HighLowRound = rnd
			match hl.phase:
				HighLowRound.Phase.CALL:
					hl.call_next(HighLowRound.Direction.HIGHER)
				HighLowRound.Phase.DECIDE:
					hl.bank()
				_:
					hl.proceed()
