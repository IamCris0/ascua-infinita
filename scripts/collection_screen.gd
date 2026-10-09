extends RefCounted
## Memorias del eclipse: daily and weekly retos, achievements with rewards,
## the collection with animated portraits, the expedition log and the
## statistics. Rules live in run_state.gd; claims go back through main.gd.

const Kit = preload("res://scripts/ui_kit.gd")
const TABS = ["Retos", "Logros", "Enemigos", "Reliquias", "Sinergias", "Arsenal", "Registro", "Estadísticas"]
const CATEGORIES = ["Enemigos", "Reliquias", "Sinergias", "Arsenal"]
# Sheet drawn for each enemy entry of the collection.
const ENEMY_ART = {"slime": "slime", "wisp": "wisp", "sentinel": "sentinel", "guardian": "guardian", "acolyte": "acolyte", "king": "boss", "bell": "bell", "forge": "forge"}

## A character breathing in its idle loop; a silhouette until discovered.
class Portrait extends Control:
	var lib
	var key: String
	var found: bool = true
	var time: float = 0.0
	var reduced_motion: bool = false
	func _ready() -> void:
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		time = randf() * 2.0
	func _process(delta: float) -> void:
		if not reduced_motion:
			time += delta
		queue_redraw()
	func _draw() -> void:
		var frame = lib.frame_at(key, "idle", time)
		var scale = minf(1.0, (size.y - 8) / maxf(1.0, lib.frame_height(key)))
		lib.draw_frame(self, key, frame, Vector2(size.x * 0.5, size.y - 4), scale, Color.WHITE if found else Color(0.02, 0.02, 0.04, 0.9))

static func badge(count: int) -> String:
	return "  (%d)" % count if count > 0 else ""

static func build(game, parent: VBoxContainer, tab: String) -> void:
	var ui = game.ui
	var state = game.state
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	parent.add_child(tabs)
	for name in TABS:
		var b = ui.button(tabs, name + badge(_tab_claims(state, name)), func(): game.show_collection(game.modal_return, name), 42, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = name == tab
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	match tab:
		"Retos": _retos(game, list)
		"Logros": _achievements(game, list)
		"Registro": _log(game, list)
		"Estadísticas": _stats(game, list)
		_: _category(game, list, tab)

## Rewards waiting in each tab, for the badges.
static func _tab_claims(state, tab: String) -> int:
	match tab:
		"Retos":
			return (state.daily + state.weekly).filter(func(m): return state.mission_done(m) and not m.claimed).size()
		"Logros":
			return state.achievements.filter(func(id): return not state.achievements_claimed.has(id)).size()
	if tab in CATEGORIES and state.category_complete(tab) and not state.collection_claimed.has(tab):
		return 1
	return 0

static func _grid(parent: Control) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	return grid

static func _card(game, grid: Control, highlight: bool) -> VBoxContainer:
	var card = game.ui.card(grid, Kit.SLATE_DARK, Kit.GOLD.darkened(0.35) if highlight else Kit.LINE, 10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	return v

## Time left until local midnight or until next Monday, as text.
static func time_left(weekly: bool) -> String:
	var now = Time.get_datetime_dict_from_system()
	var seconds = 86400 - (now.hour * 3600 + now.minute * 60 + now.second)
	if weekly:
		seconds += ((7 - (now.weekday + 6) % 7) - 1) * 86400
	var days = int(seconds / 86400.0)
	var hours = int(seconds % 86400 / 3600.0)
	var minutes = int(seconds % 3600 / 60.0)
	return "%d d %d h" % [days, hours] if days > 0 else "%d h %d min" % [hours, minutes]

static func _retos(game, list: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	ui.wrap_label(list, "Retos del día y de la semana: los mismos para todos. Progresan jugando; reclama la recompensa antes de que se renueven.", 15)
	for weekly in [false, true]:
		var missions: Array = state.weekly if weekly else state.daily
		var reward: Dictionary = state.WEEKLY_REWARD if weekly else state.DAILY_REWARD
		ui.label(list, ("RETOS SEMANALES" if weekly else "RETOS DIARIOS") + "  ·  se renuevan en " + time_left(weekly), 15, Kit.COPPER, true)
		var grid = _grid(list)
		for i in range(missions.size()):
			var mission: Dictionary = missions[i]
			var done = state.mission_done(mission)
			var v = _card(game, grid, done and not mission.claimed)
			ui.label(v, state.mission_text(mission), 18, Kit.TEXT if not mission.claimed else Kit.MUTED, true)
			var bar = ProgressBar.new()
			bar.max_value = mission.target
			bar.value = mission.progress
			bar.show_percentage = false
			bar.custom_minimum_size.y = 12
			bar.add_theme_stylebox_override("fill", Kit.flat(Kit.GOLD if done else Kit.TEAL, Color(0, 0, 0, 0), 3, 0, 0))
			v.add_child(bar)
			var row = HBoxContainer.new()
			v.add_child(row)
			ui.label(row, "%d / %d   ·   %s" % [mission.progress, mission.target, state.reward_text(reward)], 14, Kit.MUTED)
			ui.hspacer(row)
			var index = i
			var b = ui.button(row, "RECLAMADO" if mission.claimed else ("RECLAMAR" if done else "EN CURSO"), func(): game.claim_reward("weekly" if weekly else "daily", index), 38, 14)
			b.custom_minimum_size.x = 130
			b.disabled = mission.claimed or not done

static func _achievements(game, list: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	var waiting = _tab_claims(state, "Logros")
	ui.label(list, "%d de %d logros" % [state.achievements.size(), state.ACHIEVEMENTS.size()] + ("  ·  %d por reclamar" % waiting if waiting > 0 else ""), 15, Kit.COPPER, true)
	# Goals stay visible; only the unlocked ones light up.
	for group in state.ACHIEVEMENT_GROUPS:
		ui.label(list, group.to_upper(), 14, Kit.RUNE, true)
		var grid = _grid(list)
		for entry in state.ACHIEVEMENTS:
			if entry.group != group:
				continue
			var done: bool = state.achievements.has(entry.id)
			var claimed: bool = state.achievements_claimed.has(entry.id)
			var v = _card(game, grid, done and not claimed)
			ui.label(v, ("★  " if done else "☆  ") + entry.name, 18, Kit.GOLD if done else Kit.MUTED, true)
			ui.wrap_label(v, entry.description, 14, Kit.TEXT if done else Kit.MUTED)
			var row = HBoxContainer.new()
			v.add_child(row)
			ui.label(row, state.reward_text(entry.reward), 14, Kit.TEAL if done else Kit.MUTED)
			ui.hspacer(row)
			if done and not claimed:
				var id: String = entry.id
				ui.button(row, "RECLAMAR", func(): game.claim_reward("achievement", id), 36, 14).custom_minimum_size.x = 120
			elif claimed:
				ui.label(row, "✓ reclamado", 13, Kit.MUTED)

static func _category(game, list: VBoxContainer, category: String) -> void:
	var ui = game.ui
	var state = game.state
	var entries = state.collection_catalog().filter(func(entry): return entry.category == category)
	var found = entries.filter(func(entry): return state.discoveries.has(entry.id)).size()
	var head = HBoxContainer.new()
	list.add_child(head)
	ui.label(head, "%s  ·  %d / %d descubiertos" % [category.to_upper(), found, entries.size()], 15, Kit.COPPER, true)
	ui.hspacer(head)
	if state.collection_claimed.has(category):
		ui.label(head, "Recompensa reclamada", 14, Kit.MUTED)
	elif state.category_complete(category):
		ui.button(head, "RECLAMAR  ·  " + state.reward_text(state.CATEGORY_REWARD), func(): game.claim_reward("category", category), 38, 14)
	else:
		ui.label(head, "Complétala: " + state.reward_text(state.CATEGORY_REWARD), 14, Kit.MUTED)
	var grid = _grid(list)
	for entry in entries:
		var known: bool = state.discoveries.has(entry.id)
		var v = _card(game, grid, false)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		_entry_art(game, row, entry, known)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		ui.label(info, entry.name if known else "Sin descubrir", 18, Kit.GOLD if known else Kit.MUTED, true)
		ui.wrap_label(info, entry.description if known else "Encuéntralo en tus expediciones para conocerlo.", 14, Kit.TEXT if known else Kit.MUTED)
		if category == "Enemigos" and known:
			var id: String = entry.id.substr(6)
			ui.label(info, "Vencidos: %d" % int(state.bestiary.get(id, 0)), 13, Kit.TEAL)

static func _entry_art(game, row: HBoxContainer, entry: Dictionary, known: bool) -> void:
	var lib = game.lib
	var id: String = entry.id.split(":")[1]
	if entry.category == "Enemigos":
		var portrait = Portrait.new()
		portrait.lib = lib
		portrait.key = ENEMY_ART[id]
		portrait.found = known
		portrait.reduced_motion = game.state.reduced_motion
		portrait.custom_minimum_size = Vector2(92, 92)
		row.add_child(portrait)
		return
	var texture: Texture2D
	match entry.category:
		"Reliquias": texture = lib.relics[id]
		"Arsenal": texture = lib.item_icon(id)
		"Sinergias":
			for synergy in game.state.SYNERGIES:
				if synergy.id == id:
					texture = lib.relics[synergy.pair[0]]
	var slot = game.ui.icon_slot(row, texture, 72)
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if entry.category == "Arsenal" else CanvasItem.TEXTURE_FILTER_LINEAR
	if not known:
		slot.modulate = Color(0.05, 0.05, 0.08)

static func _log(game, list: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	if state.history.is_empty():
		ui.wrap_label(list, "Tus expediciones terminadas aparecerán aquí.", 15)
		return
	var grid = _grid(list)
	for run in state.history:
		var v = _card(game, grid, false)
		var oath_name = state.LEGACY[run.oath].name if run.oath >= 0 else "sin juramento"
		ui.label(v, "Cámara %d%s" % [run.room, "  ·  Eclipse %d" % run.eclipse if run.eclipse > 0 else ""], 20, Kit.GOLD, true)
		ui.label(v, state.BEARERS[run.get("bearer", "bearer")].name + "  ·  " + oath_name, 14, Kit.RUNE)
		ui.wrap_label(v, "%d enemigos  ·  %d jefes  ·  %d min %02d s  ·  +%d ascuas" % [run.kills, run.bosses, run.time / 60, run.time % 60, run.banked], 14, Kit.TEXT)

static func _stats(game, list: VBoxContainer) -> void:
	var ui = game.ui
	var state = game.state
	var minutes = int(state.total_time / 60.0)
	var rows = [
		["Expediciones", str(state.runs)], ["Mejor cámara", str(state.best)],
		["Tiempo de combate", "%d h %02d min" % [minutes / 60, minutes % 60]], ["Enemigos vencidos", str(state.total_kills)],
		["Élites vencidos", str(state.total_elites)], ["Jefes derrotados", str(state.total_bosses)],
		["Paradas perfectas", str(state.total_parries)], ["Puntos débiles", str(state.total_weak)],
		["Cargas interrumpidas", str(state.total_interrupts)], ["Corazas rotas", str(state.total_armor_breaks)],
		["Ascuas errantes", str(state.total_embers)], ["Oro reunido", game.fmt(state.total_gold)],
		["Cofres abiertos", str(state.total_chests)], ["Giros de la Rueda", str(state.total_spins)],
		["Piezas encontradas", str(state.total_items)], ["Retos completados", str(state.total_missions)],
		["Logros", "%d / %d" % [state.achievements.size(), state.ACHIEVEMENTS.size()]], ["Colección", "%d / %d" % [state.discoveries.size(), state.collection_catalog().size()]]]
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for r in rows:
		ui.label(grid, r[0], 16, Kit.MUTED)
		ui.label(grid, r[1], 18, Kit.TEXT, true)
