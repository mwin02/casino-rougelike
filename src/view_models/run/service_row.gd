class_name ServiceRow
extends RefCounted
## One deck service on the list (spec §4.1): its name, what it does, its
## price at this floor, and whether it is the one in progress.

const NAMES: Dictionary[DeckServices.Service, String] = {
	DeckServices.Service.RUMMAGE: "Rummage",
	DeckServices.Service.TOUCH_UP: "Touch-up",
	DeckServices.Service.FULL_REFORGE: "Full reforge",
	DeckServices.Service.REMOVE: "Remove a card",
	DeckServices.Service.ADD: "Add a card",
	DeckServices.Service.CLEAR_MARK: "Clear marks",
}
## The order the list shows them in.
const ORDER: Array[DeckServices.Service] = [
	DeckServices.Service.RUMMAGE, DeckServices.Service.TOUCH_UP,
	DeckServices.Service.FULL_REFORGE, DeckServices.Service.REMOVE,
	DeckServices.Service.ADD, DeckServices.Service.CLEAR_MARK,
]

var service: DeckServices.Service
var name: String
var note: String
var price_text: String
## "PER MARKED CARD"; empty for a single price.
var unit: String = ""
var selected: bool
## False when the bankroll can't cover it, or it has nothing to work on.
var enabled: bool


## The list as it stands for deck, at services' prices.
static func list(
	services: DeckServices, deck: Deck, kit: ActionKit, rules: DeckRules, selected_id: int
) -> Array[ServiceRow]:
	var marked: int = deck.marked_count()
	var notes: Dictionary[DeckServices.Service, String] = {
		DeckServices.Service.RUMMAGE: (
			"%d random cards shown: a small change to one, or skip. Paid when shown"
			% rules.rummage_cards
		),
		DeckServices.Service.TOUCH_UP: (
			"Any card, ±%d rank or a new suit" % rules.small_change_rank_step
		),
		DeckServices.Service.FULL_REFORGE: "Any card into any card",
		DeckServices.Service.REMOVE: "%s · deck minimum %d" % [
			"Flat price" if kit.flat_removals else "Dearer each time", rules.min_size
		],
		DeckServices.Service.ADD: "Any specific card",
		DeckServices.Service.CLEAR_MARK: "%d marked · lowers the heat floor" % marked,
	}
	var rows: Array[ServiceRow] = []
	for service: DeckServices.Service in ORDER:
		var row: ServiceRow = ServiceRow.new()
		row.service = service
		row.name = NAMES[service]
		row.note = notes[service]
		row.price_text = MoneyFormat.format(services.price(service))
		row.selected = service == selected_id
		row.enabled = services.bankroll - services.price(service) >= services.reserve
		rows.append(row)
	rows[3].enabled = rows[3].enabled and deck.size() > deck.min_size
	rows[5].enabled = rows[5].enabled and marked > 0
	rows[5].unit = "PER MARKED CARD"
	return rows
