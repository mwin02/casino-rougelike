class_name SettlePanel
extends PanelContainer
## A settled hand, after the design canvas's settle board: the verdict,
## where the dollars came from, the hand's efficiency (spec §1.4), then its
## heat receipt, one final whole number per row, and what the table did.

## As wide as the hand panel it takes over from, clear of the cards.
const WIDTH: float = HandPanel.WIDTH

var _rows: VBoxContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	_rows = UiKit.panel_column(self, 12, 3)


func refresh(vm: TableScreenVM) -> void:
	var result: HandResultVM = vm.result()
	if result == null:
		return
	UiKit.clear(_rows)
	var tone: Color = Palette.LOSS if result.is_loss() else Palette.GOLD
	var verdict: Label = UiKit.label(result.verdict, Fonts.Face.TITLE, 20, tone)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rows.add_child(verdict)
	for payout: HandResultVM.Payout in result.payouts:
		var ink: Color = Palette.LOSS if payout.is_loss() else Palette.WIN
		_rows.add_child(_row(payout.label, payout.amount_text(), Palette.CREAM, ink))
	_caption("THIS HAND")
	var line: Label = UiKit.label(result.efficiency_text(), Fonts.Face.NUMBER, 18, tone)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rows.add_child(line)

	var receipt: HeatReceipt = vm.receipt()
	if not receipt.rows.is_empty():
		_caption("HEAT RECEIPT")
	for row: HeatReceipt.Row in receipt.rows:
		_rows.add_child(_row(row.label, row.amount_text(), Palette.SOFT, Palette.GOLD))
	_caption("TABLE HEAT")
	var before: HeatMeterVM = vm.meter_before()
	var after: HeatMeterVM = vm.meter()
	var heat: String = "%s → %s" % [before.heat_text(), after.heat_text()]
	_rows.add_child(_row(heat, after.tier_name(), Palette.CREAM, Palette.TIERS[after.tier()]))
	for notice: String in receipt.notices:
		var told: Label = UiKit.label(notice, Fonts.Face.BODY_HEAVY, 12, Palette.GOLD)
		told.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		told.custom_minimum_size.x = WIDTH - 24.0
		_rows.add_child(told)
	reset_size()


func _caption(text: String) -> void:
	var caption: Label = UiKit.label(text, Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rows.add_child(caption)


## A label on the left and its number on the right.
func _row(label: String, amount: String, label_ink: Color, amount_ink: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var name: Label = UiKit.label(label, Fonts.Face.BODY, 12, label_ink)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name)
	row.add_child(UiKit.label(amount, Fonts.Face.NUMBER, 15, amount_ink))
	return row
