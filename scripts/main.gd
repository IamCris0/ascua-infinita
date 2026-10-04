extends Control
## Screens, HUD, menus, input and persistence. Game rules live in run_state.gd;
## the battle stage lives in arena.gd.

const RunState = preload("res://scripts/run_state.gd")
const Arena = preload("res://scripts/arena.gd")
const Kit = preload("res://scripts/ui_kit.gd")
const StonePanel = preload("res://scripts/stone_panel.gd")
const AudioDirector = preload("res://scripts/audio_director.gd")
const FlyLayer = preload("res://scripts/fly_layer.gd")
const TitleArt = preload("res://scripts/title_art.gd")
const VERSION = "0.3.0-dev"
const BUY_MODES = [1, 10, 0]
const BUY_LABELS = ["×1", "×10", "MÁX"]
const STAT_KEYS = ["click", "auto", "crit", "burst", "reward"]
const KEEPER_LINES = [
	"«Cada caída deja una brasa. Aliméntala y volverás más lejos.»",
	"«El Rey no teme a tu espada. Teme al Destello que lo interrumpe.»",
	"«Los luceros recuerdan a quien los liberó. Llévalos contigo.»",
	"«Las ascuas errantes no esperan. Atrápalas antes de que se apaguen.»",
	"«En las criptas, el eco cura a quien dejas de golpear.»",
	"«La forja paga bien su calor. Pero quema.»"
]

var state = RunState.new()
var lib
var audio
var qa_mode: bool = false
var capture_mode: bool = false
var screen: String = ""
var coin_tex: Texture2D
var title_root: Control
var title_art
var title_menu: VBoxContainer
var title_stats: Label
var game_root: Control
var arena
var fly
var gold_label: Label
var essence_label: Label
var run_essence_label: Label
var gold_box: Control
var essence_box: Control
var biome_label: Label
var room_label: Label
var room_track: Control
var hp_bar: ProgressBar
var hp_label: Label
var stat_values: Dictionary = {}
var relic_grid: GridContainer
var relic_hint: Label
var relic_signature: String = ""
var best_label: Label
var retreat_button: Button
var upgrade_cards: Array = []
var upgrade_buttons: Array[Button] = []
var buy_mode_buttons: Array[Button] = []
var buy_mode: int = 0
var burst_button: Button
var burst_fill: ProgressBar
var burst_label: Label
var log_label: Label
var status_label: Label
var rule_label: Label
var chronicle_label: Label
var next_label: Label
var pause_button: Button
var overlay: Control
var modal_panel: PanelContainer
var modal_type: String = ""
var modal_return: String = ""
var auto_save: float = 0.0
var fall_timer: float = -1.0
var retreating: bool = false
var logs: Array[String] = []
var time: float = 0.0
var last_room: int = -1
var hp_low_state: int = -1

# ================================================================ lifecycle
func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	capture_mode = "--capture" in args
	qa_mode = capture_mode or "--qa" in args
	lib = load("res://scripts/art_library.gd").shared()
	coin_tex = Kit.coin_texture()
	var restored = state.load_game() if not qa_mode else false
	if not restored:
		state.restart()
	theme = Kit.build_theme(lib)
	audio = AudioDirector.new()
	add_child(audio)
	audio.muted_for_tests = qa_mode and not capture_mode
	build_game()
	build_title()
	build_overlay()
	fly = FlyLayer.new()
	fly.coin_tex = coin_tex
	fly.shard_tex = lib.ui.shard
	fly.gold_target = gold_box
	fly.essence_target = essence_box
	add_child(fly)
	fly.arrived.connect(_on_fly_arrived)
	connect_state()
	apply_settings()
	get_tree().auto_accept_quit = false
	if restored:
		if state.offline_reward > 0:
			add_log("Tus luceros reunieron %d de oro durante tu ausencia." % int(state.offline_reward))
		state.save_game()
	if capture_mode:
		capture.call_deferred()
	elif "--qa" in args:
		start_game(false)
	else:
		show_title()

func _exit_tree() -> void:
	load("res://scripts/art_library.gd").release()

func connect_state() -> void:
	state.struck.connect(func(damage, critical, automatic):
		arena.on_struck(damage, critical, automatic)
		if not automatic:
			audio.play_hit(critical)
	)
	state.event.connect(add_log)
	state.hero_hit.connect(func(damage, heavy):
		arena.on_hero_hit(damage, heavy)
		audio.play("hurt", 0.05, 2.0 if heavy else 0.0)
		if heavy:
			audio.play("burst", 0.1, -6.0)
	)
	state.enemy_defeated.connect(func(kind, elite, boss):
		arena.on_enemy_defeated(kind, elite, boss)
		audio.play("die_" + kind, 0.06)
	)
	state.enemy_changed.connect(func():
		if state.is_boss() and screen == "game":
			audio.play("boss_appear")
	)
	state.boss_charge_started.connect(func(): audio.play("boss_charge"))
	state.boss_interrupted.connect(func(): audio.play("interrupt"))
	state.ember_spawned.connect(func(): audio.play("ember_appear"))
	state.ember_collected.connect(func(kind, _amount):
		arena.on_ember_collected(kind)
		audio.play("heal" if kind == "heal" else "ember_take")
	)
	state.relic_offered.connect(func(): audio.play("offer"))
	state.purchased.connect(func(_kind, _count): audio.play("buy", 0.06))
	state.fallen.connect(func():
		arena.on_fallen()
		if retreating:
			fall_timer = 0.35
		else:
			audio.play("fall")
			fall_timer = 1.8
	)
	arena.clicked.connect(func():
		if screen == "game":
			state.click()
	)
	arena.ember_clicked.connect(func():
		if state.collect_ember() == "":
			state.click()
	)
	arena.coins.connect(func(pos, amount, essence): fly.launch(pos, amount, essence))

func _process(delta: float) -> void:
	time += delta
	if screen == "game":
		state.tick(minf(delta, 0.1))
		if modal_type.is_empty() and Input.is_physical_key_pressed(KEY_SPACE):
			state.click()
		refresh()
		auto_save += delta
		if auto_save >= 8.0:
			auto_save = 0.0
			persist()
	if fall_timer > 0:
		fall_timer -= delta
		if fall_timer <= 0:
			fall_timer = -1.0
			show_summary()
	update_music()

func update_music() -> void:
	var track = "menu"
	if screen == "game":
		if state.dead or modal_type in ["camp", "summary"]:
			track = "camp"
		elif state.is_boss():
			track = "boss"
		else:
			track = ["garden", "crypt", "forge"][state.biome()]
	audio.play_music(track)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not qa_mode:
		if screen == "game" and state.active() and modal_type.is_empty():
			toggle_pause()

func persist() -> void:
	if not qa_mode:
		state.save_game()

func quit_game() -> void:
	if not qa_mode and not state.save_game():
		add_log("No se pudo guardar. Comprueba el espacio disponible antes de salir.")
		return
	get_tree().quit()

func apply_settings() -> void:
	audio.apply_volumes(state.master_volume, state.music_volume, state.sfx_volume)
	arena.reduced_motion = state.reduced_motion
	arena.shake_enabled = state.screen_shake
	arena.show_numbers = state.show_numbers
	fly.reduced_motion = state.reduced_motion
	title_art.reduced_motion = state.reduced_motion
	if not qa_mode:
		var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if state.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(mode)

# ================================================================ widgets
func label(parent: Node, value: String, font_size: int = 17, color: Color = Kit.TEXT, heading: bool = false) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if heading:
		l.add_theme_font_size_override("font_size", int(font_size * 1.22))
		l.add_theme_font_override("font", lib.heading_font)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.9))
	if parent:
		parent.add_child(l)
	return l

func wrap_label(parent: Node, value: String, font_size: int = 15, color: Color = Kit.MUTED) -> Label:
	var l = label(parent, value, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l

func button(parent: Node, value: String, callback: Callable, height: float = 52, font_size: int = 19) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = height
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(font_size * 1.22))
	b.pressed.connect(func():
		audio.play("ui_click", 0.04)
		callback.call()
	)
	b.mouse_entered.connect(func():
		if not b.disabled:
			audio.play("ui_hover", 0.05, 0.0, 0.03)
	)
	if parent:
		parent.add_child(b)
	return b

func small_button(parent: Node, value: String, callback: Callable) -> Button:
	var b = button(parent, value, callback, 34, 16)
	b.add_theme_stylebox_override("normal", Kit.flat(Kit.SLOT, Color("3b404c"), 5, 2, 6))
	b.add_theme_stylebox_override("hover", Kit.flat(Color("232731"), Kit.COPPER, 5, 2, 6))
	b.add_theme_stylebox_override("pressed", Kit.flat(Color("2c2218"), Kit.COPPER, 5, 2, 6))
	b.add_theme_stylebox_override("disabled", Kit.flat(Kit.SLOT, Color("23262e"), 5, 2, 6))
	return b

func stone(parent: Node, min_width: float = 0, straps: bool = true) -> VBoxContainer:
	var p = StonePanel.new()
	p.straps = straps
	p.custom_minimum_size.x = min_width
	p.add_theme_stylebox_override("panel", Kit.stone_style())
	parent.add_child(p)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(v)
	return v

func card(parent: Node, color: Color = Kit.SLATE_DARK, border: Color = Kit.LINE, margin: float = 10) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.flat(color, border, 6, 2, margin))
	parent.add_child(p)
	return p

func icon_slot(parent: Node, texture: Texture2D, side: float = 48, border: Color = Kit.LINE) -> TextureRect:
	var slot = PanelContainer.new()
	slot.add_theme_stylebox_override("panel", Kit.slot_style(border))
	slot.custom_minimum_size = Vector2(side, side)
	parent.add_child(slot)
	var t = TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.custom_minimum_size = Vector2(side - 10, side - 10)
	slot.add_child(t)
	return t

func icon(parent: Node, texture: Texture2D, side: float) -> TextureRect:
	var t = TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if texture == coin_tex else CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(t)
	return t

func spacer(parent: Node, height: float = -1) -> Control:
	var c = Control.new()
	if height < 0:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.custom_minimum_size.y = height
	parent.add_child(c)
	return c

func hspacer(parent: Node) -> Control:
	var c = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())

func header(parent: Node, overline: String, title: String) -> void:
	label(parent, overline, 14, Kit.COPPER, true)
	if not title.is_empty():
		label(parent, title, 25, Kit.TEXT, true)

# ================================================================ title
func build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)
	title_art = TitleArt.new()
	title_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(title_art)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 58)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_right", 60)
	title_root.add_child(margin)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var logo_box = VBoxContainer.new()
	logo_box.add_theme_constant_override("separation", -46)
	col.add_child(logo_box)
	var logo = label(logo_box, "ASCUA", 132, Kit.GOLD, true)
	logo.add_theme_constant_override("outline_size", 16)
	logo.add_theme_color_override("font_outline_color", Color("1a0d06"))
	logo.add_theme_constant_override("shadow_offset_y", 8)
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_color_override("font_shadow_color", Color(0.8, 0.28, 0.06, 0.6))
	var logo2 = label(logo_box, "I N F I N I T A", 50, Kit.COPPER, true)
	logo2.add_theme_constant_override("outline_size", 10)
	logo2.add_theme_color_override("font_outline_color", Color("1a0d06"))
	spacer(col, 14)
	label(col, "Un clic enciende la llama. Cada caída la hace eterna.", 19, Color("c9c2b4"))
	spacer(col, 30)
	var holder = HBoxContainer.new()
	col.add_child(holder)
	var menu_panel = StonePanel.new()
	menu_panel.custom_minimum_size.x = 400
	menu_panel.strap_size = 46
	menu_panel.add_theme_stylebox_override("panel", Kit.stone_style())
	holder.add_child(menu_panel)
	title_menu = VBoxContainer.new()
	title_menu.add_theme_constant_override("separation", 10)
	menu_panel.add_child(title_menu)
	spacer(col)
	var foot = HBoxContainer.new()
	col.add_child(foot)
	title_stats = label(foot, "", 15, Kit.MUTED)
	hspacer(foot)
	label(foot, "v" + VERSION + "  ·  Godot 4.7", 13, Color("6f7782"))

func show_title() -> void:
	screen = "title"
	close_modal(false)
	state.paused = true
	game_root.hide()
	title_root.show()
	title_art.companions = clampi(state.legacy_level(2) + 1, 1, 5)
	for child in title_menu.get_children():
		title_menu.remove_child(child)
		child.queue_free()
	label(title_menu, "EL ECLIPSE AGUARDA", 14, Kit.COPPER, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not state.dead and (state.room > 1 or state.gold > 0 or state.run_kills > 0):
		button(title_menu, "CONTINUAR  ·  CÁMARA %d" % state.room, func(): start_game(false), 58, 21)
		button(title_menu, "NUEVA EXPEDICIÓN", confirm_new_run, 52)
	elif state.dead:
		button(title_menu, "IR A LA HOGUERA", open_camp_from_title, 58, 21)
	else:
		button(title_menu, "COMENZAR EXPEDICIÓN", func(): start_game(state.dead), 58, 21)
	button(title_menu, "CÓMO JUGAR", func(): show_howto(""), 50)
	button(title_menu, "OPCIONES", func(): show_options(""), 50)
	button(title_menu, "SALIR", quit_game, 50)
	var s = "Mejor cámara: %d   ·   Expediciones: %d   ·   Enemigos vencidos: %d   ·   Reyes caídos: %d" % [state.best, state.runs, state.total_kills, state.total_bosses]
	title_stats.text = s if state.total_kills > 0 else "Tu primera expedición te espera."
	update_music()

func confirm_new_run() -> void:
	var v = modal("confirm", "NUEVA EXPEDICIÓN", "¿Abandonar este viaje?", "La expedición actual terminará en la cámara %d. Conservarás las %d ascuas que llevas; el oro, la forja y las reliquias se pierden." % [state.room, state.run_essence])
	var row = HBoxContainer.new()
	v.add_child(row)
	var a = button(row, "EMPEZAR DE NUEVO", func():
		close_modal(false)
		retreating = true
		state.finish_run()
		state.restart()
		retreating = false
		fall_timer = -1.0
		arena.on_restart()
		start_game(false)
	, 54)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = button(row, "VOLVER", func(): close_modal(), 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func open_camp_from_title() -> void:
	screen = "game"
	title_root.hide()
	game_root.show()
	arena.on_restart()
	arena.on_fallen()
	show_camp()

func start_game(new_run: bool) -> void:
	if new_run or state.dead:
		state.restart()
		arena.on_restart()
	screen = "game"
	title_root.hide()
	game_root.show()
	state.paused = false
	close_modal(false)
	refresh()
	if state.offline_reward > 0:
		arena.show_banner("LOS LUCEROS VELARON POR TI", "+%s de oro durante tu ausencia" % fmt(state.offline_reward), Kit.GOLD, 3.0)
		state.offline_reward = 0
	if state.runs == 0 and state.total_kills == 0 and not qa_mode:
		show_howto("welcome")
	persist()

# ================================================================ game HUD
func build_game() -> void:
	game_root = Control.new()
	game_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_root)
	var bg = ColorRect.new()
	bg.color = Kit.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_root.add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	game_root.add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	build_top_bar(root)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	build_bearer_panel(body)
	build_center(body)
	build_forge_panel(body)
	build_footer(root)

func build_top_bar(root: Node) -> void:
	var bar = card(root, Color("14161d"), Kit.LINE, 8)
	bar.get_theme_stylebox("panel").content_margin_left = 14
	bar.get_theme_stylebox("panel").content_margin_right = 10
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	icon(row, load("res://assets/icon.svg"), 46)
	var title = VBoxContainer.new()
	title.add_theme_constant_override("separation", -2)
	row.add_child(title)
	label(title, "ASCUA INFINITA", 26, Kit.GOLD, true)
	biome_label = label(title, "", 14, Kit.TEAL, true)
	hspacer(row)
	var mid = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	room_label = label(mid, "", 20, Kit.TEXT, true)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_track = RoomTrack.new()
	room_track.main = self
	room_track.custom_minimum_size = Vector2(330, 26)
	mid.add_child(room_track)
	hspacer(row)
	gold_box = HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 8)
	gold_box.tooltip_text = "Oro de esta expedición. Gástalo en la forja."
	gold_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(gold_box)
	icon(gold_box, coin_tex, 30)
	gold_label = label(gold_box, "0", 30, Kit.GOLD, true)
	gold_label.custom_minimum_size.x = 120
	essence_box = HBoxContainer.new()
	essence_box.add_theme_constant_override("separation", 6)
	essence_box.tooltip_text = "Ascuas: se conservan al caer o retirarte. Gástalas en la hoguera."
	essence_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(essence_box)
	icon(essence_box, lib.ui.shard, 30)
	var ev = VBoxContainer.new()
	ev.add_theme_constant_override("separation", -4)
	essence_box.add_child(ev)
	essence_label = label(ev, "0", 22, Kit.TEAL, true)
	run_essence_label = label(ev, "", 13, Color("9fd8c4"))
	essence_box.custom_minimum_size.x = 132
	pause_button = button(row, "MENÚ", toggle_pause, 52, 18)
	pause_button.custom_minimum_size.x = 110

func build_bearer_panel(body: Node) -> void:
	var left = stone(body, 300)
	left.add_theme_constant_override("separation", 8)
	header(left, "EL PORTADOR", "La última brasa")
	var hp_row = HBoxContainer.new()
	left.add_child(hp_row)
	label(hp_row, "VITALIDAD", 15, Kit.MUTED, true)
	hspacer(hp_row)
	hp_label = label(hp_row, "", 17, Kit.TEXT, true)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 18
	hp_bar.show_percentage = false
	left.add_child(hp_bar)
	spacer(left, 2)
	var names = {"click": "Daño por clic", "auto": "Luceros / s", "crit": "Crítico", "burst": "Destello", "reward": "Oro por victoria"}
	var colors = {"click": Kit.GOLD, "auto": Kit.TEAL, "crit": Kit.COPPER, "burst": Color("ffd28a"), "reward": Kit.GOLD}
	for key in STAT_KEYS:
		var row = HBoxContainer.new()
		left.add_child(row)
		label(row, names[key], 15, Kit.MUTED)
		hspacer(row)
		stat_values[key] = label(row, "", 17, colors[key], true)
	separator(left)
	label(left, "RELIQUIAS DEL VIAJE", 14, Kit.RUNE, true)
	relic_grid = GridContainer.new()
	relic_grid.columns = 5
	relic_grid.add_theme_constant_override("h_separation", 6)
	relic_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(relic_grid)
	relic_hint = wrap_label(left, "Tu primera reliquia espera al superar la cámara 5.", 14)
	spacer(left)
	best_label = wrap_label(left, "", 14)
	retreat_button = button(left, "VOLVER A LA HOGUERA", confirm_retreat, 50, 16)
	retreat_button.tooltip_text = "Termina la expedición y conserva tus ascuas."

func build_center(body: Node) -> void:
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	body.add_child(center)
	var frame = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fs = Kit.flat(Color("0c0e13"), Kit.LINE, 6, 4, 0)
	frame.add_theme_stylebox_override("panel", fs)
	center.add_child(frame)
	arena = Arena.new()
	arena.state = state
	arena.custom_minimum_size = Vector2(520, 420)
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(arena)
	burst_button = Button.new()
	burst_button.custom_minimum_size.y = 64
	burst_button.focus_mode = Control.FOCUS_NONE
	burst_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	burst_button.tooltip_text = "Destello: un golpe enorme. Contra el Rey, interrumpe su Brasa."
	burst_button.add_theme_stylebox_override("normal", Kit.button_texture(lib, Color(1.25, 0.86, 0.62)))
	burst_button.add_theme_stylebox_override("hover", Kit.button_texture(lib, Color(1.45, 1.0, 0.7)))
	burst_button.add_theme_stylebox_override("pressed", Kit.button_texture(lib, Color(1.0, 0.7, 0.5)))
	burst_button.add_theme_stylebox_override("disabled", Kit.button_texture(lib, Color(0.55, 0.52, 0.52)))
	burst_button.pressed.connect(try_burst)
	center.add_child(burst_button)
	burst_fill = ProgressBar.new()
	burst_fill.show_percentage = false
	burst_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst_fill.offset_left = 12
	burst_fill.offset_right = -12
	burst_fill.offset_top = 10
	burst_fill.offset_bottom = -12
	burst_fill.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	burst_fill.add_theme_stylebox_override("fill", Kit.flat(Color(1.0, 0.6, 0.25, 0.28), Color(0, 0, 0, 0), 4, 0, 0))
	burst_button.add_child(burst_fill)
	burst_label = label(burst_button, "", 23, Color("fff0d6"), true)
	burst_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	burst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func build_forge_panel(body: Node) -> void:
	var right = stone(body, 344)
	right.add_theme_constant_override("separation", 8)
	header(right, "FORJA DE CAMPAÑA", "Alimenta la llama")
	var modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	right.add_child(modes)
	label(modes, "Comprar", 15, Kit.MUTED)
	hspacer(modes)
	for i in range(BUY_MODES.size()):
		var b = small_button(modes, BUY_LABELS[i], func(): set_buy_mode(i))
		b.custom_minimum_size.x = 58
		buy_mode_buttons.append(b)
	label(modes, "[Q]", 13, Color("6f7782"))
	for i in range(state.UPGRADES.size()):
		build_upgrade_card(right, i)
	spacer(right, 4)
	var chron = card(right, Color("15171d"), Kit.LINE, 10)
	chron.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	chron.add_child(cv)
	label(cv, "CRÓNICA DEL VIAJE", 13, Kit.COPPER, true)
	chronicle_label = wrap_label(cv, "", 14, Color("b8b2a6"))
	chronicle_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	next_label = label(cv, "", 14, Kit.TEAL, true)
	var amb = card(right, Color("1b1a24"), Color("3a2f52"), 10)
	var av = VBoxContainer.new()
	av.add_theme_constant_override("separation", 2)
	amb.add_child(av)
	label(av, "AMBIENTE", 13, Kit.RUNE, true)
	rule_label = wrap_label(av, "", 14, Color("c8c0d8"))
	set_buy_mode(0)

func build_upgrade_card(parent: Node, kind: int) -> void:
	var data: Dictionary = state.UPGRADES[kind]
	var c = card(parent, Kit.SLATE_DARK, Kit.LINE, 8)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var ic = icon_slot(row, lib.upgrade_icon(kind), 54)
	ic.custom_minimum_size = Vector2(44, 44)
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var top = HBoxContainer.new()
	info.add_child(top)
	label(top, data.name, 17, Kit.TEXT, true)
	hspacer(top)
	var level = label(top, "", 14, Kit.GOLD, true)
	var desc = wrap_label(info, data.description, 13, Kit.MUTED)
	var cost = button(row, "", func(): purchase(kind), 54, 18)
	cost.custom_minimum_size.x = 108
	cost.icon = coin_tex
	cost.expand_icon = true
	cost.add_theme_constant_override("icon_max_width", 18)
	cost.add_theme_constant_override("h_separation", 6)
	cost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cost.tooltip_text = "Tecla [%d]" % (kind + 1)
	upgrade_cards.append({"level": level, "desc": desc, "button": cost, "card": c})
	upgrade_buttons.append(cost)

func build_footer(root: Node) -> void:
	var foot = card(root, Color("111319"), Kit.LINE, 8)
	var row = HBoxContainer.new()
	foot.add_child(row)
	log_label = label(row, "", 15, Color("c9c2b4"))
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.clip_text = true
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label(row, "CLIC/ESPACIO atacar   E destello   1-4 forja   Q cantidad   ESC menú", 13, Color("78818d"))
	status_label = label(row, "", 13, Kit.TEAL)

func set_buy_mode(index: int) -> void:
	buy_mode = index
	for i in range(buy_mode_buttons.size()):
		var on = i == index
		buy_mode_buttons[i].add_theme_stylebox_override("normal", Kit.flat(Color("2c2218") if on else Kit.SLOT, Kit.COPPER if on else Color("3b404c"), 5, 2, 6))
		buy_mode_buttons[i].add_theme_color_override("font_color", Kit.GOLD if on else Kit.MUTED)
	refresh()

func purchase_count(kind: int) -> int:
	var mode = BUY_MODES[buy_mode]
	if mode == 0:
		return maxi(1, state.affordable(kind))
	return mode

func purchase(kind: int) -> void:
	if screen != "game":
		return
	var bought = state.buy(kind, purchase_count(kind) if BUY_MODES[buy_mode] != 10 else (10 if state.affordable(kind, 10) >= 10 else 0))
	if bought > 0:
		persist()
		var c: PanelContainer = upgrade_cards[kind].card
		c.pivot_offset = c.size * 0.5
		var tw = create_tween()
		tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.06)
		tw.tween_property(c, "scale", Vector2.ONE, 0.12)
	else:
		audio.play("ui_denied", 0.0, 0.0, 0.1)

func try_burst() -> void:
	if screen != "game":
		return
	var interrupting = state.charging
	if state.burst():
		arena.on_burst(interrupting)
		audio.play("burst", 0.04)
		if interrupting:
			audio.duck(6.0, 0.6)

func refresh() -> void:
	if arena == null or status_label == null:
		return
	gold_label.text = fmt(state.gold)
	essence_label.text = str(state.essence)
	run_essence_label.text = "+%d en el viaje" % state.run_essence if not state.dead else "en la hoguera"
	biome_label.text = state.BIOMES[state.biome()]
	room_label.text = ("CÁMARA %d  ·  JEFE" if state.is_boss() else "CÁMARA %d") % state.room
	rule_label.text = state.BIOME_RULES[state.biome()]
	var to_relic = 5 - ((state.room - 1) % 5)
	var to_boss = 10 - ((state.room - 1) % 10)
	next_label.text = ("Jefe en esta cámara" if state.is_boss() else "Jefe en %d" % to_boss) + "   ·   " + ("Reliquia al vencer" if to_relic == 1 else "Reliquia en %d" % to_relic)
	hp_label.text = "%d / %d" % [ceili(state.hp), int(state.max_hp())]
	hp_bar.max_value = state.max_hp()
	hp_bar.value = state.hp
	var low = state.hp < state.max_hp() * 0.35
	if int(low) != hp_low_state:
		hp_low_state = int(low)
		hp_bar.add_theme_stylebox_override("fill", Kit.flat(Kit.DANGER if low else Color("5fcf96"), Color(0, 0, 0, 0), 3, 0, 0))
	stat_values.click.text = fmt(state.click_damage()) + (" ×2" if state.fury_time > 0 else "")
	stat_values.auto.text = fmt(state.auto_damage())
	stat_values.crit.text = "%d%%  ·  ×%.1f" % [roundi(state.critical_chance() * 100), state.critical_multiplier()]
	stat_values.burst.text = fmt(state.burst_damage())
	stat_values.reward.text = fmt(state.kill_reward())
	best_label.text = "Mejor cámara: %d   ·   Expedición nº %d" % [state.best, state.runs + (0 if state.dead else 1)]
	refresh_relics()
	for i in range(upgrade_cards.size()):
		var level: int = [state.blade, state.wisps, state.armor, state.focus][i]
		var entry: Dictionary = upgrade_cards[i]
		entry.level.text = "NV. %d" % level
		var count = 1
		var cost = float(state.price(i))
		if BUY_MODES[buy_mode] == 10:
			count = 10
			cost = state.bulk_price(i, 10)
		elif BUY_MODES[buy_mode] == 0:
			count = maxi(1, state.affordable(i))
			cost = state.bulk_price(i, count)
		var b: Button = entry.button
		b.text = fmt(cost) + ("\n×%d" % count if count > 1 else "")
		b.add_theme_font_size_override("font_size", 19 if count > 1 else 22)
		b.disabled = not state.active() or state.gold < cost
	var ready = state.burst_cooldown <= 0 and state.active()
	burst_fill.max_value = state.burst_max_cooldown()
	burst_fill.value = state.burst_max_cooldown() - state.burst_cooldown
	if state.charging:
		burst_label.text = "¡INTERRUMPIR!  DESTELLO  [E]" if state.burst_cooldown <= 0 else "DESTELLO  ·  %.1f s" % state.burst_cooldown
	elif state.burst_cooldown > 0:
		burst_label.text = "DESTELLO  ·  %.1f s" % state.burst_cooldown
	else:
		burst_label.text = "✦  DESTELLO  ·  %s  [E]" % fmt(state.burst_damage())
	burst_button.disabled = not ready
	burst_button.modulate = Color.WHITE if not ready or state.reduced_motion else Color.WHITE.lerp(Color(1.25, 1.1, 0.9), 0.5 + 0.5 * sin(time * (9.0 if state.charging else 4.0)))
	retreat_button.disabled = state.dead or not state.active()
	status_label.text = "● GUARDADO" if state.save_error.is_empty() else state.save_error
	room_track.queue_redraw()
	if screen == "game":
		if state.dead and modal_type.is_empty() and fall_timer < 0:
			show_camp()
		elif not state.offers.is_empty() and modal_type != "relic" and not state.dead:
			show_relics()
		elif state.offers.is_empty() and state.journey_phase != "" and not state.dead and modal_type != state.journey_phase:
			show_journey()
	if state.room != last_room:
		last_room = state.room

func refresh_relics() -> void:
	var signature = "|" + ",".join(state.relics)
	if signature == relic_signature:
		return
	relic_signature = signature
	for child in relic_grid.get_children():
		relic_grid.remove_child(child)
		child.queue_free()
	relic_hint.visible = state.relics.is_empty()
	for relic in state.RELICS:
		var n: int = state.count_relic(relic.id)
		if n == 0:
			continue
		var holder = Control.new()
		holder.custom_minimum_size = Vector2(48, 48)
		holder.tooltip_text = "%s%s\n%s" % [relic.name, " ×%d" % n if n > 1 else "", relic.description]
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		relic_grid.add_child(holder)
		var slot = PanelContainer.new()
		slot.add_theme_stylebox_override("panel", Kit.slot_style(Color(relic.color).darkened(0.45)))
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(slot)
		var t = TextureRect.new()
		t.texture = lib.relics[relic.id]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(t)
		if n > 1:
			var badge = label(holder, "×%d" % n, 13, Kit.GOLD, true)
			badge.position = Vector2(26, 28)

func fmt(value: float) -> String:
	if value >= 1e15:
		var exponent = floor(log(value) / log(10))
		return "%.2fe%d" % [value / pow(10, exponent), int(exponent)]
	if value >= 1e12: return "%.2fT" % (value / 1e12)
	if value >= 1e9: return "%.2fB" % (value / 1e9)
	if value >= 1e6: return "%.2fM" % (value / 1e6)
	if value >= 10000: return "%.1fk" % (value / 1000)
	if value < 100 and not is_equal_approx(value, round(value)):
		return "%.1f" % value
	return str(int(round(value)))

func add_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 6:
		logs.resize(6)
	if chronicle_label:
		chronicle_label.text = "\n".join(logs.slice(0, 5))
	if log_label:
		log_label.text = message
		log_label.modulate = Color(1.3, 1.2, 1.0)
		var tw = create_tween()
		tw.tween_property(log_label, "modulate", Color.WHITE, 0.6)

func _on_fly_arrived(kind: String) -> void:
	var target: Control = gold_label if kind == "gold" else essence_label
	target.pivot_offset = target.size * Vector2(0.2, 0.5)
	var tw = create_tween()
	tw.tween_property(target, "scale", Vector2(1.12, 1.12), 0.05)
	tw.tween_property(target, "scale", Vector2.ONE, 0.12)
	if kind == "gold":
		audio.play("coin", 0.12, -3.0, 0.07)

# ================================================================ modals
func build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.025, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var middle = CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(middle)
	modal_panel = StonePanel.new()
	modal_panel.strap_size = 64
	modal_panel.add_theme_stylebox_override("panel", Kit.stone_style())
	modal_panel.get_theme_stylebox("panel").set_content_margin_all(34)
	middle.add_child(modal_panel)
	overlay.hide()

func modal(kind: String, overline: String, title: String, description: String, width: float = 720) -> VBoxContainer:
	var was_open = overlay.visible
	modal_type = kind
	for child in modal_panel.get_children():
		modal_panel.remove_child(child)
		child.queue_free()
	modal_panel.custom_minimum_size.x = width
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	modal_panel.add_child(v)
	if not overline.is_empty():
		label(v, overline, 15, Kit.COPPER, true)
	if not title.is_empty():
		label(v, title, 38, Kit.GOLD, true)
	if not description.is_empty():
		wrap_label(v, description, 17, Color("d6d0c4"))
	separator(v)
	overlay.show()
	if not was_open:
		audio.play("ui_open")
		overlay.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(overlay, "modulate:a", 1.0, 0.16)
	return v

func close_modal(resume: bool = true) -> void:
	if overlay.visible and resume:
		audio.play("ui_close")
	overlay.hide()
	modal_type = ""
	if resume and screen == "game":
		state.paused = false
	refresh()

func modal_buttons() -> Array:
	var found: Array = []
	var stack: Array = [modal_panel]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		for c in n.get_children():
			if c is Button:
				found.append(c)
			stack.append(c)
	return found

func show_howto(return_to: String) -> void:
	modal_return = return_to
	if screen == "game":
		state.paused = true
	var welcome = return_to == "welcome"
	var v = modal("howto", "ROGUELIKE CLICKER  ·  " + ("PRIMERA EXPEDICIÓN" if welcome else "CÓMO JUGAR"), "Hasta la última ascua.", "El eclipse devoró el mundo. Tú llevas la chispa que queda.", 780)
	var tips = [
		[lib.fx_icon("slash", 2, 0.12), "Haz clic o mantén ESPACIO para atacar sin pulsar repetidamente. Ritmo máximo: un golpe cada 0,3 s. Encadenarlos suma hasta un 30% de daño."],
		[lib.upgrade_icon(1), "Empiezas con un lucero que ataca solo. Compra más en la forja; los clics aceleran el combate. Usa Q para comprar ×10 o al máximo."],
		[lib.fx_icon("critical", 1, 0.12), "DESTELLO [E] golpea por ocho. Contra el Rey sin Brasa, úsalo mientras carga su ataque para interrumpirlo."],
		[lib.relics.eye, "Cada cinco cámaras eliges una reliquia y una ruta: descansar, desafiar a un élite o visitar un evento. El combate espera tu decisión."],
		[lib.fx_icon("embers", 0, 0.1), "Atrapa las ascuas errantes que cruzan el escenario: oro, furia, vida o un Destello inmediato."],
		[lib.ui.shard, "Al caer o retirarte conservas las ascuas. En la hoguera compras mejoras permanentes y vuelves más fuerte."]
	]
	for tip in tips:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		icon_slot(row, tip[0], 50)
		var l = wrap_label(row, tip[1], 16, Kit.TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer(v, 4)
	button(v, "ENCENDER LA LLAMA" if welcome else "ENTENDIDO", func(): _return_from(modal_return), 56)

func _return_from(where: String) -> void:
	if where == "pause":
		toggle_pause_menu()
	elif screen == "title":
		close_modal(false)
	else:
		close_modal()
		persist()

func show_options(return_to: String) -> void:
	modal_return = return_to
	var v = modal("options", "AJUSTES", "Opciones", "", 640)
	var sliders = [["Volumen general", "master_volume"], ["Música", "music_volume"], ["Efectos", "sfx_volume"]]
	for s in sliders:
		var row = HBoxContainer.new()
		v.add_child(row)
		var l = label(row, s[0], 17)
		l.custom_minimum_size.x = 190
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = state.get(s[1])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var value = label(row, "%d%%" % roundi(slider.value * 100), 16, Kit.GOLD, true)
		value.custom_minimum_size.x = 56
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var key: String = s[1]
		slider.value_changed.connect(func(x):
			state.set(key, x)
			value.text = "%d%%" % roundi(x * 100)
			apply_settings()
			if key == "sfx_volume":
				audio.play("coin", 0.0, 0.0, 0.12)
		)
	separator(v)
	var toggles = [["Sacudidas de pantalla", "screen_shake"], ["Números de daño", "show_numbers"], ["Reducir movimiento y destellos", "reduced_motion"], ["Pantalla completa", "fullscreen"]]
	for t in toggles:
		var c = CheckButton.new()
		c.text = t[0]
		c.button_pressed = state.get(t[1])
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 17)
		var key: String = t[1]
		c.toggled.connect(func(on):
			state.set(key, on)
			audio.play("ui_click")
			apply_settings()
		)
		v.add_child(c)
	spacer(v, 4)
	button(v, "VOLVER", func():
		persist()
		_return_from(modal_return)
	, 54)

func toggle_pause() -> void:
	if screen != "game":
		return
	if modal_type == "pause":
		close_modal()
		return
	if not modal_type.is_empty() or state.dead:
		return
	toggle_pause_menu()

func toggle_pause_menu() -> void:
	state.paused = true
	var v = modal("pause", "UN RESPIRO JUNTO AL FUEGO", "Expedición en pausa", "Cámara %d de %s. Tu progreso se guarda automáticamente." % [state.room, state.BIOMES[state.biome()].to_lower()], 560)
	button(v, "CONTINUAR", func(): close_modal(), 56, 21)
	button(v, "OPCIONES", func(): show_options("pause"), 50)
	button(v, "CÓMO JUGAR", func(): show_howto("pause"), 50)
	button(v, "MENÚ PRINCIPAL", func():
		persist()
		show_title()
	, 50)
	button(v, "GUARDAR Y SALIR", quit_game, 50)
	wrap_label(v, "Tus luceros reúnen 2 de oro por minuto y lucero mientras no juegas (máximo 4 horas). La expedición no recibe daño con el juego cerrado.", 14)
	persist()

func show_relics() -> void:
	var v = modal("relic", "EL ECO TE OFRECE UN PACTO", "Elige tu reliquia", "Una de estas bendiciones te acompañará durante esta expedición. Teclas 1 · 2 · 3.", 980)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var n = 0
	for index in state.offers:
		n += 1
		var relic: Dictionary = state.RELICS[index]
		var color = Color(relic.color)
		var c = PanelContainer.new()
		var style = Kit.flat(Kit.SLATE_DARK, color.darkened(0.35), 8, 2, 16)
		style.border_width_top = 5
		c.add_theme_stylebox_override("panel", style)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
		var cv = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		c.add_child(cv)
		var ic = icon(cv, lib.relics[relic.id], 104)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label(cv, relic.tag, 14, color, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label(cv, relic.name, 22, Kit.TEXT, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var d = wrap_label(cv, relic.description, 16, Color("d6d0c4"))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size.y = 64
		var owned = state.count_relic(relic.id)
		label(cv, "Ya tienes ×%d" % owned if owned > 0 else "Nueva", 13, Kit.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button(cv, "ELEGIR  [%d]" % n, func(): choose_relic(index), 52)

func choose_relic(index: int) -> void:
	if state.choose_relic(index):
		audio.play("relic")
		close_modal()
		persist()

func show_journey() -> void:
	var route = state.journey_phase == "route"
	var v = modal(state.journey_phase, "CAMINOS DEL ECLIPSE  ·  CÁMARA %d" % state.room,
		"Elige tu camino" if route else state.encounter_name(),
		"El combate está detenido. Puedes decidir con calma." , 880)
	if route:
		var choices = [
			["SENDERO TRANQUILO  [1]", "Recuperas hasta un 20% de vida. El siguiente enemigo no será élite.", lib.relics.heart],
			["DESAFÍO ÉLITE  [2]", "Siguiente enemigo: ×2,2 vida y ×1,3 daño. Recompensa: ×2,5 oro y una ascua extra.", lib.relics.fang],
			["VISITAR: " + state.encounter_name().to_upper() + "  [3]", "Un encuentro opcional. Verás el trato antes de aceptarlo; puedes marcharte gratis.", lib.ui.keeper]]
		for i in range(choices.size()):
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			v.add_child(row)
			icon_slot(row, choices[i][2], 62)
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			button(col, choices[i][0], func(): choose_journey(i), 44, 17)
			wrap_label(col, choices[i][1], 15, Kit.MUTED)
	else:
		var description = "Recupera hasta un 45% de tu vida máxima, sin coste."
		var portrait = lib.relics.heart
		if state.encounter_kind == "merchant":
			description = "Un lucero adicional por %d de oro (20%% menos que en la forja). Tienes %d de oro." % [state.encounter_cost(), int(state.gold)]
			portrait = lib.ui.keeper
		elif state.encounter_kind == "altar":
			description = "Entrega %d de vida actual para ganar +20%% al daño de clics y luceros durante esta expedición. Los pactos se suman. Debes sobrevivir al pago." % state.encounter_cost()
			portrait = lib.relics.ash
		icon(v, portrait, 96).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrap_label(v, description, 18, Kit.TEXT)
		label(v, "Vida: %d / %d   ·   Pactos: %d" % [int(state.hp), int(state.max_hp()), state.altar_pacts], 16, Kit.TEAL)
		button(v, "ACEPTAR  [1]", func(): resolve_journey(true), 52).disabled = not state.can_accept_encounter()
		button(v, "SEGUIR SIN ACEPTAR  [2]", func(): resolve_journey(false), 48)
	separator(v)
	button(v, "GUARDAR Y VOLVER AL MENÚ", func():
		persist()
		show_title()
	, 42, 15)

func choose_journey(index: int) -> void:
	if state.choose_route(index):
		audio.play("ui_click")
		close_modal()
		persist()

func resolve_journey(accept: bool) -> void:
	if state.resolve_encounter(accept):
		audio.play("relic" if accept else "ui_close")
		close_modal()
		persist()

func confirm_retreat() -> void:
	if not state.active():
		return
	state.paused = true
	var v = modal("retreat", "REGRESO A LA HOGUERA", "Conserva tu chispa.", "Guardarás %d ascuas. Terminará esta expedición: perderás el oro, la forja y las reliquias del viaje." % state.run_essence, 640)
	var row = HBoxContainer.new()
	v.add_child(row)
	var a = button(row, "VOLVER Y CONSERVAR", func():
		retreating = true
		close_modal(false)
		state.paused = false
		state.finish_run()
	, 56)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = button(row, "SEGUIR EXPLORANDO", func(): close_modal(), 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func show_summary() -> void:
	var record = state.room >= state.best and state.runs > 1
	var v = modal("summary", "FIN DE LA EXPEDICIÓN", "Regreso a la hoguera" if retreating else "La llama se apaga", "Cada caída deja una brasa. Lo que aprendiste en el eclipse vuelve contigo.", 640)
	retreating = false
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var minutes = int(state.run_time / 60.0)
	var rows = [["Cámara alcanzada", str(state.room) + ("  · ¡nuevo récord!" if record else "")], ["Enemigos vencidos", str(state.run_kills)],
		["Reyes derrotados", str(state.run_bosses)], ["Oro reunido", fmt(state.run_gold)],
		["Reliquias", str(state.relics.size())], ["Duración", "%d min %02d s" % [minutes, int(state.run_time) % 60]]]
	for r in rows:
		label(grid, r[0], 17, Kit.MUTED)
		label(grid, r[1], 19, Kit.TEXT, true)
	separator(v)
	var gain = HBoxContainer.new()
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(gain)
	icon(gain, lib.ui.shard, 40)
	label(gain, "+%d ascuas" % state.run_essence, 34, Kit.TEAL, true)
	button(v, "IR A LA HOGUERA   →", func(): show_camp(), 58, 21)
	persist()

func show_camp() -> void:
	state.run_essence = 0
	var v = modal("camp", "LA HOGUERA  ·  PROGRESIÓN PERMANENTE", "Toda caída deja una brasa.", "", 1060)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var portrait = icon_slot(left, lib.ui.keeper, 220, Color("6b5a44"))
	portrait.custom_minimum_size = Vector2(206, 206)
	label(left, "EL GUARDIÁN DE LA HOGUERA", 14, Kit.COPPER, true)
	wrap_label(left, KEEPER_LINES[(state.runs + state.total_kills) % KEEPER_LINES.size()], 15, Color("d6d0c4"))
	spacer(left)
	var bank = HBoxContainer.new()
	left.add_child(bank)
	icon(bank, lib.ui.shard, 40)
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", -4)
	bank.add_child(bv)
	label(bv, str(state.essence), 36, Kit.TEAL, true)
	label(bv, "ascuas disponibles", 14, Kit.MUTED)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	row.add_child(grid)
	for i in range(state.LEGACY.size()):
		var data: Dictionary = state.LEGACY[i]
		var c = card(grid, Kit.SLATE_DARK, Kit.LINE, 10)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h = HBoxContainer.new()
		c.add_child(h)
		icon_slot(h, lib.legacy_icon(i), 58)
		var info = VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var top = HBoxContainer.new()
		info.add_child(top)
		label(top, data.name, 17, Kit.TEXT, true)
		hspacer(top)
		label(top, "NV. %d" % state.legacy_level(i), 14, Kit.GOLD, true)
		wrap_label(info, data.description, 14, Kit.MUTED)
		var maxed: bool = state.legacy_maxed(i)
		var caption = "NIVEL MÁXIMO" if maxed else "%d ascuas  [%d]" % [state.legacy_price(i), i + 1]
		var b = button(info, caption, func(): buy_legacy(i), 40, 15)
		b.disabled = maxed or state.essence < state.legacy_price(i)
	separator(v)
	var actions = HBoxContainer.new()
	v.add_child(actions)
	var menu_b = button(actions, "MENÚ PRINCIPAL", func():
		persist()
		show_title()
	, 58)
	menu_b.custom_minimum_size.x = 240
	var go = button(actions, "RENACER   →   NUEVA EXPEDICIÓN  [ENTER]", rebirth, 58, 21)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persist()

func buy_legacy(kind: int) -> void:
	if state.buy_legacy(kind):
		audio.play("relic", 0.03)
		show_camp()
		persist()
	else:
		audio.play("ui_denied")

func rebirth() -> void:
	state.restart()
	close_modal(false)
	arena.on_restart()
	audio.play("rebirth")
	state.paused = false
	refresh()
	persist()

# ================================================================ input
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo:
		return
	var key: int = e.keycode
	get_viewport().set_input_as_handled()
	if key == KEY_ESCAPE:
		match modal_type:
			"pause": close_modal()
			"options", "howto": _return_from(modal_return)
			"retreat", "confirm": close_modal(screen == "game")
			"":
				if screen == "game": toggle_pause()
		return
	if key == KEY_F11:
		state.fullscreen = not state.fullscreen
		apply_settings()
		return
	if modal_type == "relic" and key >= KEY_1 and key <= KEY_3:
		var i = key - KEY_1
		if i < state.offers.size():
			choose_relic(state.offers[i])
		return
	if modal_type == "route" and key >= KEY_1 and key <= KEY_3:
		choose_journey(key - KEY_1)
		return
	if modal_type == "event" and key in [KEY_1, KEY_2]:
		resolve_journey(key == KEY_1)
		return
	if modal_type == "camp":
		if key >= KEY_1 and key <= KEY_6:
			buy_legacy(key - KEY_1)
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			rebirth()
		return
	if modal_type == "summary" and (key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE):
		show_camp()
		return
	if screen != "game" or not modal_type.is_empty() or not state.active():
		return
	match key:
		KEY_SPACE: state.click()
		KEY_E: try_burst()
		KEY_1: purchase(0)
		KEY_2: purchase(1)
		KEY_3: purchase(2)
		KEY_4: purchase(3)
		KEY_Q: set_buy_mode((buy_mode + 1) % BUY_MODES.size())
		KEY_F:
			if state.ember_active:
				state.collect_ember()

# ================================================================ capture
func capture() -> void:
	var args = OS.get_cmdline_user_args()
	var shot = "preview"
	for a in args:
		if a.begins_with("--shot="):
			shot = a.substr(7)
	if shot == "title":
		state.best = 23
		state.runs = 4
		state.total_kills = 312
		state.total_bosses = 3
		state.legacy = [3, 2, 2, 1, 0, 0]
		state.room = 14
		state.gold = 120
		show_title()
	else:
		demo_state(shot)
		start_game(false)
		refresh()
		match shot:
			"route", "event":
				state.offers.clear()
				state.journey_phase = shot
				state.encounter_kind = "merchant"
				show_journey()
			"relic": show_relics()
			"camp":
				state.finish_run()
				fall_timer = -1.0
				show_camp()
			"summary":
				state.finish_run()
				fall_timer = -1.0
				show_summary()
			"pause": toggle_pause()
			"options": show_options("pause")
			"howto": show_howto("welcome")
	await get_tree().create_timer(1.6 if shot in ["preview", "boss", "crypt", "forge"] else 0.8).timeout
	if shot in ["preview", "boss", "crypt", "forge"]:
		for i in range(6):
			state.click()
			await get_tree().create_timer(0.07).timeout
		if shot == "boss":
			state.attack_timer = state.attack_interval() - 0.01
			state.boss_attacks = 2
		await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var out = "res://docs/" + shot + ".png"
	for a in args:
		if a.begins_with("--out="):
			out = a.substr(6)
	get_viewport().get_texture().get_image().save_png(out)
	print("CAPTURE_OK " + out)
	set_process(false)
	audio.queue_free()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func demo_state(shot: String) -> void:
	state.gold = 1840
	state.blade = 6
	state.wisps = 3
	state.armor = 2
	state.focus = 1
	state.room = {"boss": 10, "crypt": 14, "forge": 24, "route": 6, "event": 6}.get(shot, 8)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			state.room = int(a.substr(7))
	state.best = 23
	state.runs = 3
	state.essence = 46
	state.run_essence = 9
	state.total_kills = 120
	state.run_kills = 37
	state.run_gold = 5230
	state.run_time = 431
	state.run_bosses = 1
	state.legacy = [2, 1, 2, 1, 0, 1]
	state.relics = ["fang", "eye", "clock", "fang"]
	state.spawn_enemy(false)
	state.spawn_delay = 0
	state.hp = state.max_hp() * 0.78
	state.combo = 9
	state.combo_time = 1.2
	if shot == "relic":
		state.offers = [3, 6, 4]
	if shot in ["preview"]:
		state.ember_active = true
		state.ember_timer = 6.0
		state.ember_pos = Vector2(0.5, 0.22)
	arena.sync_enemy(false)
	arena.bg_index = state.biome()
	arena.bg_prev = arena.bg_index

# ================================================================ room track
class RoomTrack extends Control:
	var main
	func _draw() -> void:
		if main == null:
			return
		var s = main.state
		var start = int((s.room - 1) / 10) * 10 + 1
		var gap = size.x / 10.0
		for i in range(10):
			var r = start + i
			var c = Vector2(gap * (i + 0.5), size.y * 0.5)
			var boss = r % 10 == 0
			var done = r < s.room
			var current = r == s.room
			var radius = 8.0 if boss else 5.5
			var col = Color("2b303b")
			if done:
				col = Color("7fe0bf")
			if current:
				col = Color("f2c47c") if s.reduced_motion else Color("f2c47c").lerp(Color("fff1cf"), 0.5 + 0.5 * sin(main.time * 6.0))
			if boss and not done:
				col = Color("e0645a") if not current else col
			if i > 0:
				draw_line(Vector2(gap * (i - 0.5) + 7, c.y), Vector2(c.x - radius - 2, c.y), Color("3a404d"), 2.0)
			draw_circle(c, radius + 2.0, Color("07080b"))
			draw_circle(c, radius, col)
			if boss:
				var crown = PackedVector2Array([c + Vector2(-5, 2), c + Vector2(-5, -3), c + Vector2(-2, 0), c + Vector2(0, -4), c + Vector2(2, 0), c + Vector2(5, -3), c + Vector2(5, 2)])
				draw_colored_polygon(crown, Color("1a0d06"))
