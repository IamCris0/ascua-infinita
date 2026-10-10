extends SceneTree
## English: every text translated with the same placeholders, composed texts
## matched through their templates, and a walk through every screen in English
## that must leave no Spanish behind.
## godot --headless --path . --script tests/test_i18n.gd -- --qa --language=en
const I18n = preload("res://scripts/i18n.gd")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
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
	if not "--qa" in OS.get_cmdline_user_args() or not "--language=en" in OS.get_cmdline_user_args():
		push_error("Run with -- --qa --language=en")
		quit(1)
		return
	# The file itself.
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://locale/en.json"))
	check(data is Dictionary and data.texts.size() > 600, "locale/en.json holds the texts")
	var empty: Array = []
	var mismatched: Array = []
	for section in ["texts", "templates"]:
		for source in data[section]:
			var target: String = data[section][source]
			if target.is_empty():
				empty.append(source)
			elif I18n._placeholders(source) != I18n._placeholders(target):
				mismatched.append(source)
	check(empty.is_empty(), "Every text has its English: %s" % [empty])
	check(mismatched.is_empty(), "Translations keep the placeholders of their source: %s" % [mismatched])

	# The engine.
	var translation = I18n.install()
	TranslationServer.set_locale("en")
	var samples = {
		"OPCIONES": "OPTIONS",
		"CÁMARA 7": "CHAMBER 7",
		"CÁMARA 10  ·  JEFE  ·  ECLIPSE 2": "CHAMBER 10  ·  BOSS  ·  ECLIPSE 2",
		"Golpe en 2.6 s": "Blow in 2.6 s",
		"Logro · Primera brasa": "Achievement · First Ember",
		"ÉLITE ARDIENTE Y ESPINOSA": "BURNING AND THORNY ELITE",
		"Élite veloz · Gelatina de hollín": "swift elite · Soot Jelly",
		"1 · SENDERO DE LAS BRASAS": "1 · EMBER TRAIL",
		"Brasa Del Rey · −12 de vida": "King's Ember · −12 health",
		"Requiere Lucero heredado y Órbita veloz": "Requires Inherited Wisp and Swift Orbit",
		"Botín · Espada de ceniza (rara)": "Loot · Ash Sword (rare)",
		"1250 / 4000": "1250 / 4000",
		"Cámara 9 de jardín de las cenizas. Tu progreso se guarda automáticamente.": "Chamber 9 of the garden of ashes. Your progress saves automatically."}
	for source in samples:
		var english = TranslationServer.translate(source)
		check(english == samples[source], "%s → %s (got %s)" % [source, samples[source], english])
	TranslationServer.set_locale("es")
	check(TranslationServer.translate("OPCIONES") == "OPCIONES", "Spanish stays Spanish")
	TranslationServer.set_locale("en")
	translation.missing.clear()

	# Every screen, in English.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(TranslationServer.get_locale() == "en", "--language=en plays in English")
	var s = game.state
	s.refresh_missions(s.day_number(Time.get_date_dict_from_system()))
	s.unlock("first_kill")
	s.spawn_delay = 0
	game.refresh()
	await process_frame
	# English runs longer than Spanish: the busiest HUD must still fit.
	s.room = 17
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.relics = ["fang", "eye", "clock", "coin", "storm", "heart", "ash"]
	for line in ["¡INTERRUMPIDO! CAMPANERA VACÍA queda aturdido", "SILENCIO · Suelta clic / Espacio · luceros seguros", "Último aliento · la brasa se niega a apagarse. Destello listo y furia"]:
		game.add_log(line)
	game.refresh()
	await process_frame
	var limit: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	check(game.game_root.get_child(1).get_combined_minimum_size().y <= limit, "The busiest HUD fits in English")
	s.relics = []
	game.toggle_pause()
	for step in ["OPCIONES", "VOLVER", "CÓMO JUGAR", "ENTENDIDO"]:
		press(game, step)
		await process_frame
	for tab in game.CollectionScreen.TABS:
		game.show_collection("pause", tab)
		await process_frame
	game.show_arsenal("pause")
	s.grant_item(s.make_item("boss"))
	game.select_item(s.armory[0].uid)
	await process_frame
	game.show_arsenal("pause", "Maestrías")
	await process_frame
	game.close_modal()
	# Fights: an élite with affixes, a boss charging, the weak point and the parry cue.
	s.room = 7
	s.enemy_elite = true
	s.spawn_enemy(false)
	s.affixes = ["burning", "thorny"]
	s.spawn_delay = 0
	s.attack_timer = s.attack_interval() - 0.3
	s.weak_active = true
	s.weak_timer = 2.0
	game.refresh()
	await process_frame
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.charging = true
	s.charge_timer = 2.0
	game.refresh()
	await process_frame
	s.burst_cooldown = 0
	s.burst()
	await process_frame
	s.charging = false
	# A milestone: relic, map, chest, wheel and the events.
	s.room = 15
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	game.refresh()
	await process_frame
	press(game, "ELEGIR")
	await process_frame
	game.show_map()
	for kind in ["chest", "wheel", "shrine", "merchant", "altar", "smithy"]:
		s.offers.clear()
		s.journey_phase = "chest" if kind == "chest" else "event"
		s.encounter_kind = "" if kind == "chest" else kind
		s.gold = 1e6
		game.close_modal()
		game.refresh()
		await process_frame
		if kind == "chest":
			for i in range(3):
				game.chest_view.knock()
		elif kind == "wheel":
			press(game, "GIRAR")
		else:
			press(game, "ACEPTAR")
		await process_frame
		game.close_modal()
		s.offers.clear()
		s.journey_phase = ""
		s.encounter_kind = ""
		s.paused = false
	# The end of an expedition and the bonfire.
	game.confirm_retreat()
	await process_frame
	press(game, "VOLVER Y CONSERVAR")
	for i in range(4):
		game._process(0.2)
	await process_frame
	press(game, "IR A LA HOGUERA")
	await process_frame
	s.unlock("parry")
	game.show_bearers()
	await process_frame
	game.show_camp()
	await process_frame
	game.show_title()
	await process_frame
	var left: Array = translation.missing.keys()
	left.sort()
	check(left.is_empty(), "No Spanish left on screen:\n  " + "\n  ".join(left))
	game.queue_free()
	await process_frame
	I18n.uninstall()
	print("I18N: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
