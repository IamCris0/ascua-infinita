extends Control

const RunState = preload("res://scripts/run_state.gd")
const Arena = preload("res://scripts/arena.gd")
const INK = Color("0c111c")
const PANEL = Color("141c29")
const LINE = Color("2c3947")
const TEXT = Color("e7e5dc")
const MUTED = Color("8c9ba9")
const GOLD = Color("edbd78")
const TEAL = Color("84cdb7")

var state = RunState.new()
var arena
var hp_bar: ProgressBar
var hp_label: Label
var gold_label: Label
var essence_label: Label
var room_label: Label
var biome_label: Label
var damage_label: Label
var auto_label: Label
var crit_label: Label
var best_label: Label
var relic_label: Label
var status_label: Label
var log_label: Label
var upgrade_buttons: Array[Button] = []
var burst_button: Button
var pause_button: Button
var retreat_button: Button
var overlay: Control
var modal_panel: PanelContainer
var modal_type: String = ""
var auto_save: float = 0
var sound_timer: float = 0
var ambient_timer: float = 0
var audio_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var audio_index: int = 0
var logs: Array[String] = []
var qa_mode: bool = false

func _ready() -> void:
	qa_mode = "--capture" in OS.get_cmdline_user_args() or "--qa" in OS.get_cmdline_user_args()
	var restored = state.load_game() if not qa_mode else false
	build_theme()
	build_ui()
	build_audio()
	state.struck.connect(on_struck)
	state.event.connect(add_log)
	state.fallen.connect(func(): play_sound("fall"))
	state.enemy_changed.connect(func():
		arena.spawn_time = 0.4
		if state.total_kills > 0: play_sound("coin")
	)
	state.changed.connect(refresh)
	refresh()
	get_tree().auto_accept_quit = false
	if restored:
		add_log("Expedición recuperada. La llama sigue encendida.")
		if state.offline_reward > 0:
			add_log("Tus luceros reunieron %d oro durante tu ausencia." % int(state.offline_reward))
		# Persist the offline claim immediately, before any further exit.
		state.save_game()
	elif not qa_mode:
		show_welcome()
	else:
		add_log("Enciende la llama. Haz clic en el enemigo para atacar.")
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func build_theme() -> void:
	var t = Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff2d7"))
	t.set_color("font_disabled_color", "Button", Color("6d7d8c"))
	t.set_stylebox("normal", "Button", style(Color("1c2937"), LINE, 8))
	t.set_stylebox("hover", "Button", style(Color("2c3d4b"), GOLD, 8))
	t.set_stylebox("pressed", "Button", style(Color("364d58"), TEAL, 8))
	t.set_stylebox("disabled", "Button", style(Color("151e2b"), Color("25313e"), 8))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD, 8))
	t.set_stylebox("background", "ProgressBar", style(Color("0b121d"), LINE, 4))
	t.set_stylebox("fill", "ProgressBar", style(TEAL, TEAL, 4))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 16)
	theme = t

func style(color: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func label(parent: Node, value: String, font_size: int = 17, color: Color = TEXT) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func wrap_label(parent: Node, value: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var l = label(parent, value, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(parent: Node, value: String, callback: Callable, height: float = 48) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = height
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func card(parent: Node, min_width: float = 0) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	panel.add_theme_stylebox_override("panel", style(PANEL, LINE))
	parent.add_child(panel)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(v)
	return v

func spacer(parent: Node) -> void:
	var c = Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func separator(parent: Node) -> void:
	var line = HSeparator.new()
	line.add_theme_color_override("separator", LINE)
	parent.add_child(line)

func build_ui() -> void:
	var background = ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var header = HBoxContainer.new()
	root.add_child(header)
	var icon = TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(67, 67)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var title = VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	label(title, "A S C U A   I N F I N I T A", 31, GOLD)
	label(title, "UN CLIC ENCIENDE LA LLAMA. CADA CAÍDA LA HACE ETERNA.", 12, MUTED)
	var currency = VBoxContainer.new()
	currency.custom_minimum_size.x = 190
	currency.add_theme_constant_override("separation", 2)
	header.add_child(currency)
	gold_label = label(currency, "", 24, GOLD)
	essence_label = label(currency, "", 14, TEAL)
	pause_button = button(header, "Ⅱ  PAUSA", toggle_pause, 52)
	separator(root)
	var expedition = HBoxContainer.new()
	root.add_child(expedition)
	biome_label = label(expedition, "", 15, TEAL)
	biome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_label = label(expedition, "", 15, MUTED)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var left = card(body, 230)
	label(left, "EL PORTADOR", 13, TEAL)
	label(left, "La última brasa", 23)
	wrap_label(left, "Desciende. Reúne ascuas.\nVuelve más fuerte.", 15)
	separator(left)
	hp_label = label(left, "", 17)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 10
	hp_bar.show_percentage = false
	left.add_child(hp_bar)
	damage_label = label(left, "", 16, GOLD)
	auto_label = label(left, "", 16, TEAL)
	crit_label = label(left, "", 16, MUTED)
	separator(left)
	label(left, "RELIQUIAS DEL VIAJE", 12, MUTED)
	relic_label = wrap_label(left, "", 14, TEXT)
	spacer(left)
	best_label = wrap_label(left, "", 14, MUTED)
	retreat_button = button(left, "↻  VOLVER A LA HOGUERA", confirm_retreat, 48)
	retreat_button.add_theme_font_size_override("font_size", 13)
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var arena_panel = PanelContainer.new()
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var arena_style = style(Color("101723"), LINE, 5)
	arena_style.set_content_margin_all(0)
	arena_panel.add_theme_stylebox_override("panel", arena_style)
	center.add_child(arena_panel)
	arena = Arena.new()
	arena.state = state
	arena.custom_minimum_size = Vector2(560, 470)
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.clicked.connect(func(): state.click())
	arena_panel.add_child(arena)
	burst_button = button(center, "", func(): state.burst(), 52)
	burst_button.add_theme_stylebox_override("normal", style(Color("423123"), Color("8c623e")))
	var right = card(body, 264)
	right.add_theme_constant_override("separation", 7)
	label(right, "FORJA DE CAMPAÑA", 13, GOLD)
	label(right, "Alimenta la llama", 22)
	wrap_label(right, "Invierte el oro de esta expedición.", 15)
	separator(right)
	var names = ["01   FILO DE ASCua", "02   LUCERO GUARDIÁN", "03   PIEL DE OBSIDIANA"]
	var descriptions = ["+3,5 daño por clic", "+2,5 daño automático / s", "+15 vida máxima · cura 30\nBloquea 2 de daño por golpe"]
	for i in range(3):
		label(right, names[i].to_upper(), 14, TEXT)
		wrap_label(right, descriptions[i], 14)
		var b = button(right, "", func(): purchase(i), 46)
		upgrade_buttons.append(b)
		if i < 2: separator(right)
	spacer(right)
	wrap_label(right, "EL LEGADO PERMANECE\nLas ascuas se conservan al caer o retirarte. Gástalas en la hoguera.", 13, TEAL)
	var footer = card(root)
	footer.add_theme_constant_override("separation", 7)
	log_label = label(footer, "", 14, MUTED)
	log_label.max_lines_visible = 2
	var bottom = HBoxContainer.new()
	footer.add_child(bottom)
	label(bottom, "CLIC / ESPACIO  atacar     E  destello     1 · 2 · 3  mejorar     ESC  pausa", 12, MUTED)
	status_label = label(bottom, "", 12, TEAL)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.07, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var middle = CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(middle)
	modal_panel = PanelContainer.new()
	modal_panel.custom_minimum_size.x = 710
	modal_panel.add_theme_stylebox_override("panel", style(PANEL, Color("6b6250"), 14))
	middle.add_child(modal_panel)
	overlay.hide()

func refresh() -> void:
	if arena == null:
		return
	gold_label.text = "%s  ORO" % format_number(state.gold)
	essence_label.text = "%d ascuas  ·  +%d en el viaje" % [state.essence, state.run_essence]
	biome_label.text = "●  " + state.BIOMES[state.biome()]
	room_label.text = "CÁMARA %02d     /     JEFE EN %d" % [state.room, 10 - ((state.room - 1) % 10)]
	hp_label.text = "VITALIDAD    %d / %d" % [ceili(state.hp), int(state.max_hp())]
	hp_bar.max_value = state.max_hp()
	hp_bar.value = state.hp
	damage_label.text = "%s   daño por clic" % format_number(state.click_damage())
	auto_label.text = "%s   daño automático / s" % format_number(state.auto_damage())
	crit_label.text = "%d%%   probabilidad crítica" % roundi(state.critical_chance() * 100)
	best_label.text = "Mejor cámara: %d\nExpediciones: %d" % [state.best, state.runs + (0 if state.dead else 1)]
	var owned: Array[String] = []
	for relic in state.RELICS:
		var n: int = state.count_relic(relic.id)
		if n > 0:
			owned.append("◆ " + relic.name + (" ×%d" % n if n > 1 else ""))
	relic_label.text = "\n".join(owned) if not owned.is_empty() else "Tu primera reliquia espera\nal superar la cámara 5."
	for i in range(3):
		var level: int = [state.blade, state.wisps, state.armor][i]
		upgrade_buttons[i].text = "NV. %d    ·    %s ORO   [%d]" % [level, format_number(state.price(i)), i + 1]
		upgrade_buttons[i].disabled = not state.active() or state.gold < state.price(i)
	burst_button.text = "✦  DESTELLO   ·   %.1f s" % state.burst_cooldown if state.burst_cooldown > 0 else "✦  DESTELLO   ·   DAÑO ×8   [ E ]"
	burst_button.disabled = not state.active() or state.burst_cooldown > 0
	retreat_button.disabled = state.dead
	status_label.text = "● GUARDADO AUTOMÁTICO" if state.save_error.is_empty() else state.save_error
	if state.dead and modal_type != "camp":
		show_camp()
	elif not state.offers.is_empty() and modal_type != "relic":
		show_relics()

func format_number(value: float) -> String:
	if value >= 1000000000: return "%.1fB" % (value / 1000000000)
	if value >= 1000000: return "%.1fM" % (value / 1000000)
	if value >= 10000: return "%.1fk" % (value / 1000)
	return str(int(value)) if is_equal_approx(value, round(value)) else "%.1f" % value

func purchase(kind: int) -> void:
	if state.buy(kind):
		play_sound("coin")
		persist()

func add_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 2: logs.resize(2)
	log_label.text = "\n".join(logs)

func modal(kind: String, overline: String, title: String, description: String) -> VBoxContainer:
	modal_type = kind
	for child in modal_panel.get_children():
		modal_panel.remove_child(child)
		child.queue_free()
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	modal_panel.add_child(v)
	label(v, overline, 14, TEAL)
	label(v, title, 34, GOLD)
	wrap_label(v, description, 17, TEXT)
	separator(v)
	overlay.show()
	return v

func close_modal() -> void:
	overlay.hide()
	modal_type = ""
	state.paused = false
	refresh()

func show_welcome() -> void:
	state.paused = true
	var v = modal("welcome", "ROGUELIKE CLICKER  /  PRIMERA EXPEDICIÓN", "Hasta la última ascua.", "El eclipse devoró el mundo. Tú llevas la chispa que queda.")
	label(v, "01    Haz clic en el escenario o pulsa ESPACIO para atacar.", 17)
	label(v, "02    Gasta oro en filo, luceros automáticos y armadura.", 17)
	label(v, "03    Elige reliquias. Vence al jefe de cada diez cámaras.", 17)
	label(v, "04    Al caer, tus ascuas compran mejoras permanentes.", 17)
	wrap_label(v, "Puedes retirarte a la hoguera en cualquier momento. El oro y las reliquias pertenecen al viaje; tu legado dura para siempre.", 15)
	button(v, "ENCENDER LA LLAMA   →", func(): close_modal(); persist(), 58)

func show_relics() -> void:
	var v = modal("relic", "EL ECO TE OFRECE UN PACTO", "Elige tu reliquia", "Una de estas bendiciones te acompañará durante esta expedición.")
	for index in state.offers:
		var relic: Dictionary = state.RELICS[index]
		var b = button(v, "%s   ·   %s\n%s" % [relic.tag, relic.name, relic.description], func():
			if state.choose_relic(index):
				play_sound("relic")
				close_modal()
				persist()
		, 84)
		b.add_theme_color_override("font_color", Color(relic.color))
	persist()

func show_camp() -> void:
	var v = modal("camp", "LA HOGUERA  /  PROGRESIÓN PERMANENTE", "Toda caída deja una brasa.", "Llegaste a la cámara %d. Conservas %d ascuas para fortalecer tu legado." % [state.room, state.essence])
	var names = ["BRASA INTERIOR", "CORAZÓN ETERNO", "PACTO ESTELAR"]
	var descriptions = ["+2 al daño base por clic", "+20 de vida inicial", "+1 de daño por lucero"]
	for i in range(3):
		var b = button(v, "%s  ·  NV. %d  ·  %d ASCUAS\n%s" % [names[i], state.legacy[i], state.legacy_price(i), descriptions[i]], func():
			if state.buy_legacy(i):
				play_sound("relic")
				show_camp()
				persist()
		, 72)
		b.disabled = state.essence < state.legacy_price(i)
	button(v, "RENACER   →   NUEVA EXPEDICIÓN", func():
		# Clear the camp before emitting restart's state change.
		overlay.hide()
		modal_type = ""
		state.restart()
		persist()
	, 58)
	persist()

func confirm_retreat() -> void:
	if not state.active(): return
	state.paused = true
	var v = modal("retreat", "REGRESO A LA HOGUERA", "Conserva tu chispa.", "Guardarás %d ascuas. Terminará esta expedición: perderás el oro, las mejoras de campaña y las reliquias del viaje." % state.run_essence)
	button(v, "VOLVER Y CONSERVAR LAS ASCUAS", func(): state.finish_run(), 56)
	button(v, "SEGUIR EXPLORANDO", close_modal)

func toggle_pause() -> void:
	if modal_type == "pause":
		close_modal()
		return
	if not modal_type.is_empty(): return
	state.paused = true
	var v = modal("pause", "UN RESPIRO JUNTO AL FUEGO", "Expedición en pausa", "Tu progreso se guarda automáticamente. Puedes continuar cuando quieras.")
	var sound = CheckButton.new()
	sound.text = "Sonido activado"
	sound.button_pressed = not state.muted
	sound.toggled.connect(func(enabled): state.muted = not enabled; update_mute(); persist())
	v.add_child(sound)
	var motion = CheckButton.new()
	motion.text = "Reducir movimiento y sacudidas"
	motion.button_pressed = state.reduced_motion
	motion.toggled.connect(func(enabled): state.reduced_motion = enabled; persist())
	v.add_child(motion)
	wrap_label(v, "Los luceros reúnen 2 de oro por minuto y nivel durante tu ausencia (máximo 4 horas). La expedición no recibe daño mientras el juego está cerrado.", 15)
	button(v, "CONTINUAR", close_modal, 56)
	button(v, "GUARDAR Y SALIR", quit_game)
	persist()

func _process(delta: float) -> void:
	state.tick(minf(delta, 0.1))
	sound_timer = maxf(0, sound_timer - delta)
	auto_save += delta
	if auto_save >= 8:
		auto_save = 0
		persist()
	ambient_timer += delta
	if ambient_timer >= 5:
		ambient_timer = 0
		if state.active(): play_sound("pulse")

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode == KEY_ESCAPE:
		if modal_type == "retreat": close_modal()
		else: toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not state.active(): return
	match e.keycode:
		KEY_SPACE: state.click()
		KEY_E: state.burst()
		KEY_1: purchase(0)
		KEY_2: purchase(1)
		KEY_3: purchase(2)
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not qa_mode:
		if state.active(): toggle_pause()

func persist() -> void:
	if not qa_mode:
		state.save_game()

func quit_game() -> void:
	if not qa_mode and not state.save_game():
		add_log("No se pudo guardar. Comprueba el espacio disponible antes de salir.")
		refresh()
		return
	get_tree().quit()

func build_audio() -> void:
	for sound in ["hit", "critical", "coin", "relic", "fall", "pulse"]:
		sounds[sound] = load("res://assets/audio/" + sound + ".wav")
	for i in range(8):
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
	update_mute()

func update_mute() -> void:
	AudioServer.set_bus_mute(0, state.muted)

func play_sound(key: String) -> void:
	if state.muted or audio_players.is_empty() or (qa_mode and "--capture" not in OS.get_cmdline_user_args()): return
	var player = audio_players[audio_index % audio_players.size()]
	audio_index += 1
	player.stream = sounds[key]
	player.play()

func on_struck(damage: float, critical: bool, automatic: bool) -> void:
	arena.impact(damage, critical, automatic)
	if sound_timer <= 0 and not automatic:
		play_sound("critical" if critical else "hit")
		sound_timer = 0.06

func capture_preview() -> void:
	state.gold = 146
	state.blade = 3
	state.wisps = 2
	state.armor = 1
	state.room = 8
	state.hp = 91
	state.best = 18
	state.essence = 12
	state.run_essence = 7
	state.relics = ["fang"]
	state.spawn_enemy()
	refresh()
	var filename = "preview"
	if "--camp" in OS.get_cmdline_user_args():
		state.finish_run()
		filename = "camp"
	elif "--relic" in OS.get_cmdline_user_args():
		state.offers = [0, 1, 3]
		refresh()
		filename = "relic"
	elif "--welcome" in OS.get_cmdline_user_args():
		show_welcome()
		filename = "welcome"
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/" + filename + ".png")
	print("CAPTURE_OK")
	get_tree().quit()
