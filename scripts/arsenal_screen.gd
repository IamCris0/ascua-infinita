extends RefCounted
## The Arsenal: equipped pieces, the stored ones and the selected piece's
## sheet, plus the skill masteries. Rules live in run_state.gd; actions go
## back through main.gd, which rebuilds this screen after each one.

const Kit = preload("res://scripts/ui_kit.gd")
const TABS = ["Equipo", "Maestrías"]
const MASTERY_ICONS = {"burst_power": ["fx", "critical"], "burst_haste": ["relic", "storm"], "guard_window": ["upgrade", 2],
	"riposte": ["fx", "slash"], "firm_guard": ["relic", "heart"], "weak_eye": ["relic", "eye"]}

static func rarity_color(state, item: Dictionary) -> Color:
	return Color(state.RARITY_COLORS[item.rarity])

static func build(game, parent: VBoxContainer, tab: String) -> void:
	var ui = game.ui
	var state = game.state
	var lib = game.lib
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	parent.add_child(head)
	for name in TABS:
		var b = ui.button(head, name.to_upper(), func(): game.show_arsenal(game.modal_return, name), 44, 17)
		b.custom_minimum_size.x = 180
		b.disabled = name == tab
	ui.hspacer(head)
	ui.icon(head, lib.item_icon("scrap"), 34)
	ui.label(head, str(state.scrap), 30, Color("c9d3dd"), true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.label(head, "esquirlas", 15, Kit.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tab == "Maestrías":
		_masteries(game, parent)
	else:
		_equipment(game, parent)

static func _equipment(game, parent: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	# Equipped pieces.
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	ui.label(left, "EQUIPADO", 14, Kit.COPPER, true)
	for slot in state.SLOTS:
		_slot_card(game, left, slot)
	ui.wrap_label(left, "Las piezas se conservan al caer. Puedes cambiarlas cuando quieras desde la pausa o la hoguera.", 13)
	# Stored pieces.
	var middle = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	row.add_child(middle)
	ui.label(middle, "ARSENAL  ·  %d / %d" % [state.armory.size(), state.ARMORY_SIZE], 14, Kit.COPPER, true)
	if state.armory.is_empty():
		ui.wrap_label(middle, "Aún no tienes piezas. Los jefes siempre dejan una; los élites y los cofres, a veces.", 15)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	middle.add_child(grid)
	var sorted: Array = state.armory.duplicate()
	sorted.sort_custom(func(a, b): return a.rarity > b.rarity or (a.rarity == b.rarity and (a.level > b.level or (a.level == b.level and a.uid < b.uid))))
	for item in sorted:
		_tile(game, grid, item)
	# Sheet of the selected piece.
	var right = VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	_sheet(game, right)

static func _slot_card(game, parent: Control, slot: String) -> void:
	var ui = game.ui
	var state = game.state
	var item: Dictionary = state.equipped_item(slot)
	var border = rarity_color(state, item) if not item.is_empty() else Kit.LINE
	var card = ui.card(parent, Kit.SLATE_DARK, border, 8)
	var selected = not item.is_empty() and game.arsenal_selected == item.uid
	if selected:
		card.add_theme_stylebox_override("panel", Kit.flat(Color("2a2430"), border, 6, 3, 8))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon = ui.icon_slot(row, game.lib.item_icon(item.base) if not item.is_empty() else null, 60, border)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	ui.label(info, state.SLOT_NAMES[slot].to_upper(), 12, Kit.MUTED, true)
	if item.is_empty():
		ui.label(info, "Vacío", 18, Kit.MUTED, true)
		ui.label(info, "Equipa una pieza del arsenal", 13, Kit.MUTED)
		return
	ui.label(info, state.item_name(item), 18, rarity_color(state, item), true)
	ui.label(info, "%s  ·  Nv. %d/%d" % [state.item_stat_text(item), item.level, state.max_item_level(item)], 13, Kit.TEXT)
	if not item["trait"].is_empty():
		ui.label(info, state.TRAITS[item["trait"]].name, 13, Kit.RUNE, true)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			game.select_item(item.uid)
	)

static func _tile(game, grid: GridContainer, item: Dictionary) -> void:
	var state = game.state
	var color = rarity_color(state, item)
	var b = Button.new()
	b.custom_minimum_size = Vector2(76, 76)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.icon = game.lib.item_icon(item.base)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("icon_max_width", 52)
	var selected = game.arsenal_selected == item.uid
	var bg = Color("2a2430") if selected else Kit.SLOT
	b.add_theme_stylebox_override("normal", Kit.flat(bg, color, 6, 4 if selected else 2, 8))
	b.add_theme_stylebox_override("hover", Kit.flat(Color("232733"), color.lightened(0.2), 6, 3, 8))
	b.add_theme_stylebox_override("pressed", Kit.flat(bg, color, 6, 3, 8))
	b.tooltip_text = "%s (%s)\n%s" % [state.item_name(item), state.RARITIES[item.rarity].to_lower(), state.item_stat_text(item)]
	b.pressed.connect(func(): game.select_item(item.uid))
	grid.add_child(b)
	var level = game.ui.label(b, "+%d" % item.level if item.level > 0 else "", 14, Kit.GOLD, true)
	level.position = Vector2(6, 52)
	if state.is_equipped(item.uid):
		var mark = game.ui.label(b, "E", 14, Kit.TEAL, true)
		mark.position = Vector2(58, 2)
	if not item["trait"].is_empty():
		var dot = game.ui.label(b, "✦", 14, Kit.RUNE, true)
		dot.position = Vector2(6, 2)

static func _sheet(game, parent: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	var item: Dictionary = state.item_by_uid(game.arsenal_selected)
	ui.label(parent, "PIEZA", 14, Kit.COPPER, true)
	if item.is_empty():
		ui.wrap_label(parent, "Elige una pieza para ver sus detalles, equiparla, mejorarla o desguazarla.", 15)
		return
	var color = rarity_color(state, item)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	parent.add_child(top)
	var icon = ui.icon_slot(top, game.lib.item_icon(item.base), 88, color)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var names = VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	ui.label(names, state.item_name(item), 22, color, true)
	ui.label(names, "%s  ·  %s" % [state.RARITIES[item.rarity], state.SLOT_NAMES[state.ITEMS[item.base].slot]], 14, Kit.MUTED)
	ui.label(names, "Nivel %d de %d" % [item.level, state.max_item_level(item)], 14, Kit.GOLD, true)
	ui.label(parent, state.item_stat_text(item), 18, Kit.TEXT, true)
	if item.level < state.max_item_level(item):
		var next = item.duplicate()
		next.level += 1
		ui.label(parent, "Al mejorar: " + state.item_stat_text(next), 14, Kit.TEAL)
	if not item["trait"].is_empty():
		ui.label(parent, state.TRAITS[item["trait"]].name, 16, Kit.RUNE, true)
		ui.wrap_label(parent, state.TRAITS[item["trait"]].text, 14, Color("cdbff0"))
	var equipped = state.is_equipped(item.uid)
	var slot: String = state.ITEMS[item.base].slot
	if equipped:
		ui.button(parent, "QUITAR", func(): game.arsenal_action("unequip", item.uid), 46, 17)
	else:
		ui.button(parent, "EQUIPAR", func(): game.arsenal_action("equip", item.uid), 46, 17)
	var maxed = item.level >= state.max_item_level(item)
	var up = ui.button(parent, "NIVEL MÁXIMO" if maxed else "MEJORAR  ·  %d ESQUIRLAS" % state.upgrade_cost(item), func(): game.arsenal_action("upgrade", item.uid), 46, 17)
	up.disabled = maxed or state.scrap < state.upgrade_cost(item)
	var scrap = ui.button(parent, "DESGUAZAR  ·  +%d ESQUIRLAS" % state.salvage_value(item), func(): game.arsenal_action("salvage", item.uid), 46, 17)
	scrap.disabled = equipped
	if equipped:
		scrap.tooltip_text = "Quítatela antes de desguazarla."
	elif not state.equipped_item(slot).is_empty():
		ui.wrap_label(parent, "Sustituirá a %s." % state.item_name(state.equipped_item(slot)), 13)

static func _masteries(game, parent: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	ui.wrap_label(parent, "Mejoras permanentes de tus técnicas. Se pagan con esquirlas, que se consiguen al desguazar piezas, de los jefes y en algunos cofres.", 15)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	for i in range(state.MASTERIES.size()):
		var entry: Dictionary = state.MASTERIES[i]
		var level = state.mastery(entry.id)
		var card = ui.card(grid, Kit.SLATE_DARK, Kit.GOLD.darkened(0.4) if level > 0 else Kit.LINE, 10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		ui.icon_slot(row, mastery_icon(game, entry.id), 54)
		var info = VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		ui.label(info, entry.name, 18, Kit.TEXT, true)
		ui.label(info, entry.text, 13, Kit.MUTED)
		ui.label(info, "■ ".repeat(level) + "□ ".repeat(entry.max - level), 15, Kit.GOLD)
		var maxed = level >= entry.max
		var b = ui.button(row, "MÁXIMO" if maxed else "%d" % state.mastery_cost(i), func(): game.arsenal_action("mastery", i), 50, 18)
		b.custom_minimum_size.x = 96
		if not maxed:
			b.icon = game.lib.item_icon("scrap")
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 22)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.disabled = maxed or state.scrap < state.mastery_cost(i)

static func mastery_icon(game, id: String) -> Texture2D:
	var spec: Array = MASTERY_ICONS.get(id, ["upgrade", 0])
	match spec[0]:
		"fx": return game.lib.fx_icon(spec[1], 2 if spec[1] == "slash" else 1, 0.12)
		"relic": return game.lib.relics[spec[1]]
	return game.lib.upgrade_icon(spec[1])
