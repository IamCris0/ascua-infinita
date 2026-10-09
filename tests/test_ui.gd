extends SceneTree
## Integration: screens, buttons and modals wired to the rules.
## godot --headless --path . --script tests/test_ui.gd -- --qa
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func press(game, text: String) -> bool:
	for b in game.modal_buttons():
		if b.text.begins_with(text) and not b.disabled:
			b.pressed.emit()
			return true
	return false

func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("Run with -- --qa to isolate user saves")
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var s = game.state
	check(game.screen == "game" and game.game_root.visible, "QA mode opens the expedition")
	s.spawn_delay = 0
	var initial: float = s.enemy_hp
	game.arena.clicked.emit()
	check(s.enemy_hp == initial and game.arena.hero.playing("attack"), "Click starts anticipation before damage")
	s.tick(s.HIT_DELAY)
	check(s.enemy_hp < initial, "Arena click lands at contact")
	s.gold = 100
	game.refresh()
	game.upgrade_buttons[1].pressed.emit()
	check(s.wisps == 2, "Upgrade button adds to the starting companion")
	s.gold = 5000
	game.set_buy_mode(2)
	var before = s.blade
	game.upgrade_buttons[0].pressed.emit()
	check(s.blade > before + 3 and s.gold < s.price(0), "MAX mode spends all it can")
	game.set_buy_mode(0)
	game.toggle_pause()
	check(s.paused and game.modal_type == "pause", "Pause opens the menu")
	check(press(game, "OPCIONES") and game.modal_type == "options", "Options open from pause")
	check(press(game, "VOLVER") and game.modal_type == "pause", "Options return to pause")
	game.toggle_pause()
	check(s.active() and not game.overlay.visible, "Pause resumes")
	s.room = 5
	s.damage_enemy(1e9)
	game.refresh()
	check(game.modal_type == "relic" and game.overlay.visible, "Relic chooser opens")
	check(press(game, "GUARDAR Y VOLVER") and game.screen == "title" and s.offers.size() == 3, "Relic choice can be suspended at the title")
	game.start_game(false)
	check(game.modal_type == "relic", "Continue returns to the pending relic choice")
	check(press(game, "ELEGIR") and s.relics.size() == 1 and game.modal_type == "map", "Relic button opens the map")
	check(not s.active() and press(game, "GUARDAR Y VOLVER") and game.screen == "title", "The map can be suspended at the title")
	game.start_game(false)
	check(game.modal_type == "map", "Continue returns to the pending map")
	s.lanes[0] = ["merchant", "fight", "fight", "fight"]
	check(press(game, "1 ·") and s.lane == 0 and game.modal_type == "event", "A lane button chooses the lane and opens its first event")
	var companions = s.wisps
	check(press(game, "ACEPTAR") and s.wisps == companions + 1 and s.active(), "Merchant purchase grants one companion and resumes combat")
	game.show_map()
	check(game.modal_type == "map_view" and s.paused, "The chamber track opens the map of the stretch")
	var esc_key = InputEventKey.new()
	esc_key.keycode = KEY_ESCAPE
	esc_key.pressed = true
	game._unhandled_key_input(esc_key)
	check(game.modal_type.is_empty() and s.active(), "Esc closes the map and resumes")
	# A chest: knock, reveal, continue.
	s.journey_phase = "chest"
	s.chest_tier = 1
	game.refresh()
	check(game.modal_type == "chest" and not s.active(), "A chest chamber opens the chest screen")
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	for i in range(3):
		game._unhandled_key_input(space)
	check(game.chest_view.is_open() and s.total_chests == 1 and s.paused, "Knocking opens the chest while combat waits")
	game.refresh()
	check(game.modal_type == "chest", "The rewards stay on screen")
	await create_timer(2.2).timeout
	check(press(game, "CONTINUAR") and game.modal_type != "chest", "Continue leaves the chest")
	if game.modal_type == "relic":
		press(game, "ELEGIR")
	check(s.active(), "Combat resumes after the chest")
	# The Rueda del eclipse.
	s.journey_phase = "event"
	s.encounter_kind = "wheel"
	s.gold = 100000
	game.refresh()
	check(game.modal_type == "wheel", "A wheel chamber opens the Rueda")
	var digit = InputEventKey.new()
	digit.keycode = KEY_1
	digit.pressed = true
	game._unhandled_key_input(digit)
	check(s.total_spins == 1 and game.wheel_view.spinning() and s.paused, "1 spins the wheel while combat waits")
	await create_timer(4.0).timeout
	check(not game.wheel_view.spinning() and game.wheel_view.sector_at_pointer() == s.wheel_result, "The wheel stops on the sector the rules chose")
	check(press(game, "CONTINUAR") and game.modal_type != "wheel", "Continue leaves the Rueda")
	for i in range(3):
		if game.modal_type == "relic":
			press(game, "ELEGIR")
		elif game.modal_type == "chest":
			for k in range(3):
				game.chest_view.knock()
			await create_timer(2.2).timeout
			press(game, "CONTINUAR")
	check(s.active(), "Combat resumes after the Rueda")
	# The Arsenal, from the pause menu.
	game.toggle_pause()
	check(press(game, "ARSENAL") and game.modal_type == "arsenal" and s.paused, "The pause menu opens the arsenal")
	var found = s.make_item("boss")
	s.grant_item(found)
	game.select_item(found.uid)
	check(press(game, "EQUIPAR") and s.is_equipped(found.uid), "The sheet equips the selected piece")
	s.scrap = 1000
	game.show_arsenal("pause")
	check(press(game, "MEJORAR") and found.level == 1, "The sheet upgrades the piece")
	check(press(game, "QUITAR") and not s.is_equipped(found.uid), "The sheet takes the piece off")
	check(press(game, "DESGUAZAR") and s.item_by_uid(found.uid).is_empty() and game.arsenal_selected == -1, "The sheet salvages a stored piece")
	check(press(game, "MAESTRÍAS") and game.modal_type == "arsenal", "The masteries tab opens")
	game.arsenal_action("mastery", 0)
	check(s.mastery("burst_power") == 1, "A mastery level is bought from its tab")
	check(press(game, "VOLVER") and game.modal_type == "pause", "Back returns to the pause menu")
	game.toggle_pause()
	check(s.active(), "Combat resumes after the arsenal")
	# Retos, from the pause menu.
	s.refresh_missions(s.day_number(Time.get_date_dict_from_system()))
	s.daily[0].progress = s.daily[0].target
	game.toggle_pause()
	var menu: Array = game.modal_buttons().map(func(b): return b.text)
	check(menu.any(func(t): return t.begins_with("RETOS Y COLECCIÓN") and t.ends_with(")")), "The pause menu shows waiting rewards")
	check(press(game, "RETOS Y COLECCIÓN") and game.modal_type == "collection", "The pause menu opens the retos")
	var banked = s.essence
	check(press(game, "RECLAMAR") and s.daily[0].claimed and s.essence > banked, "A finished reto is claimed from its card")
	check(press(game, "VOLVER") and game.modal_type == "pause", "Back to the pause menu")
	game.toggle_pause()
	s.spawn_delay = 0
	s.burst_cooldown = 0
	game.try_burst()
	check(s.burst_cooldown > 0, "Destello button triggers the burst")
	s.ember_active = true
	game.arena.ember_clicked.emit()
	check(not s.ember_active and s.total_embers == 1, "Clicking an ember collects it")
	s.spawn_delay = 0
	s.parry_cooldown = 0
	s.attack_timer = s.attack_interval() - 0.2
	s.stun_time = 0
	s.charging = false
	if s.next_is_heavy():
		s.boss_attacks += 1
	game.refresh()
	check(game.parry_label.text.begins_with("¡PARA!") and not game.parry_button.disabled, "The parry button calls the moment to guard")
	var guard_key = InputEventKey.new()
	guard_key.keycode = KEY_R
	guard_key.pressed = true
	game._unhandled_key_input(guard_key)
	check(s.parry_window > 0, "R raises the guard")
	game.refresh()
	check(game.parry_label.text == "GUARDIA ALZADA", "The parry button shows the raised guard")
	s.weak_active = true
	s.weak_timer = 2.0
	s.click_cooldown = 0
	game.arena.weak_clicked.emit()
	check(not s.weak_active and s.total_weak == 1, "Clicking the weak point strikes it")
	game.confirm_retreat()
	check(game.modal_type == "retreat" and s.paused, "Retreat asks for confirmation")
	var bank = s.run_essence
	check(press(game, "VOLVER Y CONSERVAR") and s.dead, "Retreat ends the expedition")
	for i in range(4):
		game._process(0.2)
	check(game.modal_type == "summary", "The expedition summary appears")
	check(s.essence >= bank, "Ascuas are banked on retreat")
	check(press(game, "IR A LA HOGUERA") and game.modal_type == "camp", "Summary leads to the bonfire")
	s.essence = 100
	game.show_camp()
	var level = s.legacy_level(3)
	game.buy_legacy(3)
	check(s.legacy_level(3) == level + 1, "Permanent upgrades are bought at the bonfire")
	s.legacy[5] = 10
	s.essence = 10000
	game.show_camp()
	var capped_button = false
	for b in game.modal_buttons():
		if b.text == "NIVEL MÁXIMO":
			capped_button = b.disabled
	check(capped_button, "The capped permanent upgrade is labelled and disabled")
	s.unlock("parry")
	game.show_camp()
	check(press(game, "PORTADOR") and game.modal_type == "bearers", "The bonfire opens the bearers")
	check(press(game, "ELEGIR") and s.bearer == "sentinel" and game.arena.hero.hue == s.BEARERS.sentinel.hue, "A bearer card chooses that bearer and recolours the figure")
	check(press(game, "VOLVER A LA HOGUERA") and game.modal_type == "camp", "Back to the bonfire")
	var pressed = press(game, "RENACER")
	check(pressed and s.active() and s.room == 1 and not game.overlay.visible, "Rebirth starts a new expedition")
	check(game.bearer_label.text == "La Centinela", "The HUD names the bearer")
	game.show_title()
	check(game.screen == "title" and game.title_root.visible and not game.game_root.visible, "Main menu is shown")
	var labels: Array = []
	for b in game.title_menu.get_children():
		if b is Button:
			labels.append(b.text)
	check(labels.size() >= 4, "Main menu lists its options")
	game.start_game(false)
	check(game.screen == "game" and s.active(), "Continue returns to the expedition")
	# Late in an expedition the HUD holds every relic, all synergies and long
	# chronicle lines; it must still fit the smallest logical viewport.
	s.relics = ["fang", "eye", "clock", "coin", "storm", "heart", "ash"]
	for line in ["¡INTERRUMPIDO! CAMPANERA VACÍA queda aturdido", "SILENCIO · Suelta clic / Espacio · luceros seguros", "Último aliento · la brasa se niega a apagarse. Destello listo y furia"]:
		game.add_log(line)
	game.refresh()
	await process_frame
	var limit: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	check(game.game_root.get_child(1).get_combined_minimum_size().y <= limit, "A busy HUD never pushes the footer off screen")
	s.relics = []
	game.refresh()
	s.room = 30
	s.discoveries.erase("enemy:forge")
	s.spawn_enemy(false)
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_key_input(esc)
	check(not s.paused and game.modal_type.is_empty() and s.spawn_delay <= s.INTRO_SKIP_LEFT, "Esc skips a boss entrance instead of pausing")
	s.room = 1
	s.spawn_enemy(false)
	game.show_options("")
	game.state.music_volume = 0.2
	game.apply_settings()
	var bus = AudioServer.get_bus_index("Music")
	check(bus >= 0 and AudioServer.get_bus_volume_db(bus) < -10, "Music volume applies to its bus")
	s.reduced_motion = true
	game.apply_settings()
	game.title_art._process(0.0)
	var title_time: float = game.title_art.time
	var ember_position: Vector2 = game.title_art.embers[0].pos
	game.title_art._process(0.5)
	check(game.title_art.time == title_time and game.title_art.embers[0].pos == ember_position and game.title_art.hero.speed == 0, "Reduced motion freezes the title backdrop and idle animation")
	game.refresh()
	check(game.burst_button.modulate == Color.WHITE, "Reduced motion removes the burst button pulse")
	game.close_modal()
	s.spawn_delay = 0
	s.wisps = 0
	s.enemy_hp = 100000
	s.click_cooldown = 0
	var held = InputEventKey.new()
	held.keycode = KEY_SPACE
	held.physical_keycode = KEY_SPACE
	held.pressed = true
	Input.parse_input_event(held)
	await create_timer(0.75).timeout
	check(s.enemy_hp <= 100000 - 2 * s.click_damage(), "Holding Space repeats attacks without repeated key presses")
	s.paused = true
	var paused_hp = s.enemy_hp
	await create_timer(0.35).timeout
	check(s.enemy_hp == paused_hp, "Held attack cannot bypass pause")
	held.pressed = false
	Input.parse_input_event(held)
	# Hit-stops are off in QA runs; enable them for one call (no save happens).
	s.reduced_motion = false
	game.qa_mode = false
	game.hitstop(0.05)
	game.qa_mode = true
	check(Engine.time_scale < 0.1, "A hit-stop slows the action")
	await create_timer(0.12, true, false, true).timeout
	check(Engine.time_scale == 1.0, "The action resumes on its own after a hit-stop")
	s.reduced_motion = true
	game.qa_mode = false
	game.hitstop(0.05)
	game.qa_mode = true
	check(Engine.time_scale == 1.0, "Reduced motion has no hit-stops")
	print("UI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
