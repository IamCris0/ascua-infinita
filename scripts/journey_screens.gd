extends RefCounted
## Screens between fights: the map of lanes, chests, the Rueda del eclipse and
## the other encounters. Rules live in run_state.gd; main.gd owns the modal.

const Kit = preload("res://scripts/ui_kit.gd")
const MapView = preload("res://scripts/map_view.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const WheelView = preload("res://scripts/wheel_view.gd")

## Opens the screen the pending journey phase asks for.
static func show(game) -> void:
	match game.state.journey_phase:
		"map": show_map(game, false)
		"chest": show_chest(game)
		"event":
			if game.state.encounter_kind == "wheel":
				show_wheel(game)
			else:
				show_event(game)

## The lanes after a milestone. Read-only, it is the map of the current stretch.
static func show_map(game, read_only: bool) -> void:
	var state = game.state
	var ui = game.ui
	if read_only:
		state.paused = true
	var last = state.lane_start + state.LANE_LENGTH
	var v = game.modal("map_view" if read_only else "map", "CAMINOS DEL ECLIPSE  ·  CÁMARAS %d–%d" % [state.lane_start, last],
		"Mapa del tramo" if read_only else "Elige tu camino",
		"Cada camino recorre cuatro cámaras y termina en %s. Pasa el ratón por un icono para ver qué guarda; en todas hay combate." % ("el jefe" if last % 10 == 0 else "otra reliquia"), 1140)
	var map = MapView.new()
	map.state = state
	map.lib = game.lib
	map.read_only = read_only
	map.reduced_motion = state.reduced_motion
	v.add_child(map)
	if read_only:
		ui.button(v, "VOLVER", func(): game.close_modal(), 48)
		return
	map.lane_chosen.connect(func(i): game.choose_lane(i))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for i in range(state.LANES.size()):
		var b = ui.button(row, "%d · %s" % [i + 1, state.LANES[i].name.to_upper()], func(): game.choose_lane(i), 50, 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", MapView.LANE_COLORS[i].lightened(0.25))
		b.mouse_entered.connect(func(): map.hovered_lane = i)
		b.mouse_exited.connect(func(): map.hovered_lane = -1)
	game.suspend_button(v)
	game.audio.play("map_open")

static func show_chest(game) -> void:
	var state = game.state
	var v = game.modal("chest", "CÁMARA %d  ·  ANTES DEL COMBATE" % state.room, state.CHEST_NAMES[state.chest_tier], "", 760)
	var view = ChestView.new()
	view.lib = game.lib
	view.audio = game.audio
	view.tier = state.chest_tier
	view.reduced_motion = state.reduced_motion
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The fight waits until the rewards have been seen.
	view.open_loot = func():
		var loot = state.open_chest()
		state.paused = true
		game.persist()
		return loot
	view.icon_for = func(entry): return loot_icon(game, entry)
	view.text_for = func(entry): return state.loot_text(entry)
	v.add_child(view)
	game.chest_view = view
	var go = game.ui.button(v, "CONTINUAR  [ENTER]", func(): game.finish_loot(), 54)
	go.disabled = true
	view.finished.connect(func(): go.disabled = false)
	game.suspend_button(v)

static func show_wheel(game) -> void:
	var state = game.state
	var cost = state.encounter_cost()
	var v = game.modal("wheel", "CÁMARA %d  ·  ANTES DEL COMBATE" % state.room, "Rueda del eclipse",
		"Apuesta %d de oro y gira. Los diez sectores son iguales: cada uno sale una vez de cada diez. Tienes %d de oro." % [cost, int(state.gold)], 780)
	var view = WheelView.new()
	view.lib = game.lib
	view.audio = game.audio
	view.sectors = state.WHEEL
	view.names = state.WHEEL_NAMES
	view.reduced_motion = state.reduced_motion
	view.icon_for = func(kind): return sector_icon(game, kind)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(view)
	game.wheel_view = view
	var outcome = game.ui.label(v, "", 24, Kit.GOLD, true)
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var go = game.ui.button(v, "CONTINUAR  [ENTER]", func(): game.finish_loot(), 54)
	go.hide()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	v.move_child(row, go.get_index())
	var suspend = game.suspend_button(v)
	var spin = game.ui.button(row, "GIRAR  ·  %d DE ORO  [1]" % cost, func():
		if view.spinning() or view.result >= 0 or not state.resolve_encounter(true):
			return
		state.paused = true
		row.hide()
		suspend.hide()
		view.spin(state.wheel_result)
		game.persist()
	, 54)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.disabled = not state.can_accept_encounter()
	var leave = game.ui.button(row, "MARCHARSE  [2]", func(): game.resolve_journey(false), 54)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.finished.connect(func(index):
		var entry: Dictionary = state.last_loot[0] if not state.last_loot.is_empty() else {"kind": "nothing"}
		outcome.text = state.WHEEL_NAMES[state.WHEEL[index]] + ("  ·  esta vez la rueda no da nada" if entry.kind == "nothing" else "  ·  " + state.loot_text(entry))
		outcome.add_theme_color_override("font_color", Kit.MUTED if entry.kind == "nothing" else Kit.GOLD)
		go.show()
	)

## Santuario, mercader and altar: the deal is shown before accepting it.
static func show_event(game) -> void:
	var state = game.state
	var ui = game.ui
	var v = game.modal("event", "CÁMARA %d  ·  ANTES DEL COMBATE" % state.room, state.encounter_name(), "El combate está detenido. Puedes decidir con calma.", 880)
	var description = "Recupera hasta un %d%% de tu vida máxima, sin coste." % roundi(state.shrine_heal() * 100)
	if state.encounter_kind == "merchant":
		description = "Un lucero adicional por %d de oro (20%% menos que en la forja). Tienes %d de oro." % [state.encounter_cost(), int(state.gold)]
	elif state.encounter_kind == "altar":
		description = "Entrega %d de vida actual para ganar +20%% al daño de clics y luceros durante esta expedición. Los pactos se suman. Debes sobrevivir al pago." % state.encounter_cost()
	var art = ui.icon_slot(v, encounter_art(game), 200, Color("6b5a44"))
	art.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if state.encounter_kind == "shrine" and not state.reduced_motion:
		# The lit shrine flickers between its two burning states.
		var flicker = art.create_tween().set_loops()
		flicker.tween_callback(func(): art.texture = game.lib.event_art(2)).set_delay(0.35)
		flicker.tween_callback(func(): art.texture = game.lib.event_art(1)).set_delay(0.35)
	ui.wrap_label(v, description, 18, Kit.TEXT)
	ui.label(v, "Vida: %d / %d   ·   Pactos: %d" % [int(state.hp), int(state.max_hp()), state.altar_pacts], 16, Kit.TEAL)
	ui.button(v, "ACEPTAR  [1]", func(): game.resolve_journey(true), 52).disabled = not state.can_accept_encounter()
	ui.button(v, "SEGUIR SIN ACEPTAR  [2]", func(): game.resolve_journey(false), 48)
	game.suspend_button(v)

## Encounter illustration, lit so it reads at small sizes too.
static func encounter_art(game) -> Texture2D:
	match game.state.encounter_kind:
		"merchant": return game.lib.portrait("merchant")
		"altar": return game.lib.event_art(5)
	return game.lib.event_art(1)

static func loot_icon(game, entry: Dictionary) -> Texture2D:
	match entry.kind:
		"gold": return game.coin_tex
		"essence": return game.lib.ui.shard
		"heal": return game.lib.relics.heart
		"wisp": return game.lib.upgrade_icon(1)
		"forge": return game.lib.upgrade_icon(int(entry.amount))
		"relic": return game.lib.map_icon("milestone")
		"chest": return game.lib.map_icon("chest")
	return null

static func sector_icon(game, kind: String) -> Texture2D:
	match kind:
		"gold2", "gold3": return game.coin_tex
		"heal": return game.lib.relics.heart
		"relic": return game.lib.map_icon("milestone")
		"chest": return game.lib.map_icon("chest")
		"essence": return game.lib.ui.shard
	return game.lib.map_icon("elite")
