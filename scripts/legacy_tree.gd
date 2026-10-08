extends RefCounted
## The bonfire's Constelación del Legado: the keeper and the ascua bank, the
## shared upgrades, then three branches (root, two nodes and an oath) side by
## side. Rules live in run_state.gd; purchases go back through main.gd.

const Kit = preload("res://scripts/ui_kit.gd")
const BRANCHES = [
	["filo", "FILO", "Clics y cadenas · nace de Brasa interior", Color("f2c47c")],
	["luceros", "LUCEROS", "Compañeros automáticos", Color("7fe0bf")],
	["brasa", "BRASA", "Supervivencia y Destello", Color("ec8a6d")]]
# Each branch column from top to bottom: root, two nodes, oath.
const LAYOUT = {"filo": [6, 7, 8], "luceros": [2, 9, 10, 11], "brasa": [1, 5, 12, 13]}
const SHARED = [0, 3, 4]

static func build(game, parent: Control) -> void:
	var ui = game.ui
	var state = game.state
	var lib = game.lib
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 260
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var keeper = HBoxContainer.new()
	keeper.add_theme_constant_override("separation", 10)
	left.add_child(keeper)
	var portrait = ui.icon_slot(keeper, lib.ui.keeper, 96, Color("6b5a44"))
	portrait.custom_minimum_size = Vector2(86, 86)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	keeper.add_child(words)
	ui.label(words, "EL GUARDIÁN", 14, Kit.COPPER, true)
	ui.wrap_label(words, game.KEEPER_LINES[(state.runs + state.total_kills) % game.KEEPER_LINES.size()], 14, Color("d6d0c4"))
	var bank = HBoxContainer.new()
	bank.add_theme_constant_override("separation", 8)
	left.add_child(bank)
	ui.icon(bank, lib.ui.shard, 34)
	ui.label(bank, str(state.essence), 32, Kit.TEAL, true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.label(bank, "ascuas disponibles", 14, Kit.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.label(left, "COMÚN", 13, Kit.MUTED, true)
	for kind in SHARED:
		node_card(game, left, kind, Kit.GOLD)
	var tree = VBoxContainer.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.add_theme_constant_override("separation", 8)
	row.add_child(tree)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	tree.add_child(columns)
	for branch in BRANCHES:
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		columns.add_child(column)
		ui.label(column, branch[1], 17, branch[3], true)
		ui.label(column, branch[2], 13, Kit.MUTED)
		ui.spacer(column, 6)
		var nodes: Array = LAYOUT[branch[0]]
		for i in range(nodes.size()):
			if i > 0:
				var link = Link.new()
				link.lit = state.legacy_unlocked(nodes[i])
				link.color = branch[3]
				column.add_child(link)
			node_card(game, column, nodes[i], branch[3])

static func node_card(game, parent: Control, kind: int, accent: Color) -> void:
	var ui = game.ui
	var state = game.state
	var data: Dictionary = state.LEGACY[kind]
	var level: int = state.legacy_level(kind)
	var oath: bool = state.is_oath(kind)
	var sworn: bool = oath and state.oath == kind
	var c: PanelContainer = ui.card(parent, Kit.SLATE_DARK, accent.darkened(0.25) if sworn else (accent.darkened(0.6) if oath else Kit.LINE), 8)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.tooltip_text = "%s\n%s\nNivel %d de %d" % [data.name, data.description, level, data.max]
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	c.add_child(h)
	ui.icon_slot(h, game.lib.legacy_icon(kind), 42)
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var top = HBoxContainer.new()
	info.add_child(top)
	ui.label(top, data.name, 15, Kit.TEXT, true)
	ui.hspacer(top)
	ui.label(top, "JURAMENTO" if oath else "%d/%d" % [level, data.max], 12, accent if oath else Kit.GOLD, true)
	ui.wrap_label(info, data.description, 12, Kit.MUTED)
	var caption = "%d ascuas" % state.legacy_price(kind)
	var action = func(): game.buy_legacy(kind)
	var enabled = state.can_buy_legacy(kind)
	if oath and level > 0:
		caption = "JURAMENTO ACTIVO" if sworn else "ACTIVAR"
		action = func(): game.swear(kind)
		enabled = not sworn
	elif state.legacy_maxed(kind):
		caption = "NIVEL MÁXIMO"
	elif not state.legacy_unlocked(kind):
		caption = requirement_text(state, kind)
	var b: Button = ui.button(info, caption, action, 30, 13)
	b.disabled = not enabled
	if not state.legacy_unlocked(kind) and level == 0:
		c.modulate = Color(1, 1, 1, 0.6)

## "Requiere Brasa interior 3" / "Requiere Ojo templado y Cadena larga".
static func requirement_text(state, kind: int) -> String:
	var missing: Array[String] = []
	for requirement in state.LEGACY[kind].requires:
		if state.legacy_level(requirement[0]) < requirement[1]:
			var name: String = state.LEGACY[requirement[0]].name
			missing.append(name + (" %d" % requirement[1] if requirement[1] > 1 else ""))
	return "Requiere " + " y ".join(missing)

# The rail between two nodes of a branch; lit once the lower node is unlocked.
class Link extends Control:
	var lit: bool = false
	var color: Color = Color.WHITE
	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var x = 31.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), color if lit else Color("3a404d"), 3.0)
