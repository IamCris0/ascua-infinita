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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var s = game.state
	check(game.screen == "game" and game.game_root.visible, "QA mode opens the expedition")
	s.spawn_delay = 0
	var initial: float = s.enemy_hp
	game.arena.clicked.emit()
	check(s.enemy_hp < initial, "Arena click is wired to combat")
	s.gold = 100
	game.refresh()
	game.upgrade_buttons[1].pressed.emit()
	check(s.wisps == 1, "Upgrade button is wired")
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
	check(press(game, "ELEGIR") and s.relics.size() == 1 and not game.overlay.visible, "Relic button applies selection")
	s.spawn_delay = 0
	s.burst_cooldown = 0
	game.try_burst()
	check(s.burst_cooldown > 0, "Destello button triggers the burst")
	s.ember_active = true
	game.arena.ember_clicked.emit()
	check(not s.ember_active and s.total_embers == 1, "Clicking an ember collects it")
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
	var pressed = press(game, "RENACER")
	check(pressed and s.active() and s.room == 1 and not game.overlay.visible, "Rebirth starts a new expedition")
	game.show_title()
	check(game.screen == "title" and game.title_root.visible and not game.game_root.visible, "Main menu is shown")
	var labels: Array = []
	for b in game.title_menu.get_children():
		if b is Button:
			labels.append(b.text)
	check(labels.size() >= 4, "Main menu lists its options")
	game.start_game(false)
	check(game.screen == "game" and s.active(), "Continue returns to the expedition")
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
	print("UI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
