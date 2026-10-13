class_name TableHud
extends Control
## The table's standing panels, to the design canvas: which table this is
## (top left) with the floor's hand clock, the bankroll (top right) with the
## floor's quota, and the heat meter (left).

const GUTTER: float = 44.0
const METER_TOP: float = 104.0

var _subtitle: Label
var _title: Label
var _clock: Label
var _bankroll: Label
var _quota: Label
var _bankroll_panel: PanelContainer
var _table_panel: PanelContainer
var _meter: HeatMeter
## The bankroll panel's stake-window extras: the bar and the totals under it.
var _stake_bar: Control
var _stake_total: Label
var _stake_left: Label
var _stake_rows: Array[Control] = []
## Heat in the table panel, while the meter is away.
var _heat_row: HBoxContainer
var _heat: Label
var _tier: Label
var _shares: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var table: VBoxContainer = _panel(Vector2(GUTTER, 12.0), -1.5)
	_table_panel = table.get_parent()
	_subtitle = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_title = UiKit.label("", Fonts.Face.TITLE, 19, Palette.CREAM)
	_clock = UiKit.label("", Fonts.Face.BODY_HEAVY, 12, Palette.CREAM)
	for label: Label in [_subtitle, _title, _clock]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		table.add_child(label)
	_heat_row = HBoxContainer.new()
	_heat_row.add_theme_constant_override("separation", 5)
	table.add_child(_heat_row)
	_heat = UiKit.label("", Fonts.Face.LABEL, 11, Palette.MUTED)
	_heat_row.add_child(_heat)
	_tier = UiKit.chip("", Palette.TIERS[0], HeatMeter.TIER_INK)
	_heat_row.add_child(_tier)

	var money: VBoxContainer = _panel(Vector2.ZERO, 1.0)
	_bankroll_panel = money.get_parent()
	_bankroll_panel.custom_minimum_size.x = 188.0
	var row: HBoxContainer = HBoxContainer.new()
	money.add_child(row)
	var caption: Label = UiKit.label("BANKROLL", Fonts.Face.LABEL, 11, Palette.MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(caption)
	_bankroll = UiKit.label("", Fonts.Face.NUMBER, 21, Palette.CREAM)
	row.add_child(_bankroll)
	_quota = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	_quota.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(_quota)
	_stake_bar = Control.new()
	_stake_bar.custom_minimum_size.y = 11.0
	_stake_bar.draw.connect(_draw_stake_bar)
	money.add_child(_stake_bar)
	var totals: HBoxContainer = HBoxContainer.new()
	money.add_child(totals)
	_stake_total = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	_stake_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stake_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	totals.add_child(_stake_total)
	_stake_left = UiKit.label("", Fonts.Face.BODY_HEAVY, 11, Palette.MUTED)
	totals.add_child(_stake_left)
	_stake_rows = [_stake_bar, totals]

	_meter = HeatMeter.new()
	_meter.position = Vector2(GUTTER, METER_TOP)
	add_child(_meter)


func refresh(vm: TableScreenVM) -> void:
	_subtitle.text = vm.subtitle()
	_title.text = vm.title()
	_clock.text = vm.clock_text()
	_clock.visible = not _clock.text.is_empty()
	_bankroll.text = vm.bankroll_text()
	var staking: bool = vm.stage() == TableScreenVM.Stage.STAKE
	for extra: Control in _stake_rows:
		extra.visible = staking
	_heat_row.visible = staking
	_quota.text = vm.quota_text()
	_quota.visible = not staking and not _quota.text.is_empty()
	var meter: HeatMeterVM = vm.meter()
	_heat.text = "HEAT " + meter.heat_text()
	_tier.text = meter.tier_name()
	var ground: StyleBoxFlat = _tier.get_theme_stylebox("normal")
	ground.bg_color = Palette.TIERS[meter.tier()]
	_bankroll_panel.custom_minimum_size.x = 300.0 if staking else 188.0
	if staking:
		var stake: StakeVM = vm.stake()
		_shares = stake.shares()
		_stake_total.text = "Bet + sides = " + MoneyFormat.format(stake.total())
		_stake_left.text = MoneyFormat.format(stake.room()) + " left"
		_stake_bar.queue_redraw()
	_bankroll_panel.reset_size()
	_bankroll_panel.position = Vector2(size.x - GUTTER - _bankroll_panel.size.x, 12.0)
	_meter.show_meter(meter)


## The Tricks screen has no table or bankroll panel, only the meter.
func show_panels(shown: bool) -> void:
	_bankroll_panel.visible = shown
	_table_panel.visible = shown
	# With the panels gone the meter moves up, clear of the bottom button.
	_meter.position.y = METER_TOP if shown else METER_TOP - 44.0


## Keeps the meter above bottom, where the bet sits, on any screen.
func fit_meter(bottom: float) -> void:
	_meter.fit(bottom - _meter.position.y)


## The stake window shows heat in the stake panel's place instead.
func show_meter(shown: bool) -> void:
	_meter.visible = shown


## The bankroll as a bar: the opening bet in gold, the side bets in teal.
func _draw_stake_bar() -> void:
	var rect: Rect2 = Rect2(0.0, 0.0, _stake_bar.size.x, 10.0)
	_stake_bar.draw_style_box(UiKit.filled(Palette.OUTLINE, 5), rect)
	var inner: Rect2 = rect.grow(-2.0)
	_stake_bar.draw_style_box(UiKit.filled(Palette.WELL, 3), inner)
	var bet: float = inner.size.x * _shares.x
	var sides: float = inner.size.x * _shares.y
	_stake_bar.draw_rect(Rect2(inner.position, Vector2(bet, inner.size.y)), Palette.GOLD)
	var after: Vector2 = inner.position + Vector2(bet, 0.0)
	_stake_bar.draw_rect(Rect2(after, Vector2(sides, inner.size.y)), Palette.TEAL)


## A dark panel set a touch askew, as if pinned up; returns its column.
func _panel(at: Vector2, tilt: float) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.panel(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.rotation_degrees = tilt
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", -3)
	panel.add_child(column)
	return column
