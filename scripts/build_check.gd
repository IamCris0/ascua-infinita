extends RefCounted
## Explicit package smoke check; never reads or writes the player's save.
func run(game) -> void:
	game.set_process(false)
	var failures: Array[String] = []
	if game.lib.characters.size() < 5 or game.lib.backgrounds.size() != 3:
		failures.append("Missing character or background resources")
	if game.lib.map_icons == null or game.lib.chests == null:
		failures.append("Missing map icons or chests")
	if game.audio.streams.size() != game.audio.SFX.size() or game.audio.music.size() != game.audio.TRACKS.size():
		failures.append("Missing audio")
	for path in ["res://assets/art/atlas.json", "res://assets/art/imagegen/characters.json"]:
		if not FileAccess.file_exists(path):
			failures.append("Missing manifest: " + path)
	var State = load("res://scripts/run_state.gd")
	if "--verify-build" in OS.get_cmdline_user_args():
		var sample = State.new()
		sample.restart()
		sample.room = 20
		sample.spawn_enemy(false)
		sample.spawn_delay = 0
		sample.gold = 321
		sample.relics = ["fang", "eye"]
		sample.remember_relics()
		sample.boss_attacks = 1
		sample.charging = true
		sample.charge_timer = 1.25
		sample.bell_resonance = 2
		if not sample.save_game("user://build-check.json"):
			failures.append("Cannot save fixture")
	var restored = State.new()
	if not restored.load_game("user://build-check.json", false):
		failures.append("Cannot load fixture")
	elif restored.gold != 321 or restored.room != 20 or not restored.charging or restored.charge_timer != 1.25 or restored.bell_resonance != 2 or not restored.discoveries.has("enemy:bell") or not restored.has_synergy("precision"):
		failures.append("Persistence mismatch")
	if DisplayServer.get_name() != "headless":
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		if game.get_viewport().get_texture().get_image().save_png("user://build-preview.png") != OK:
			failures.append("Cannot capture renderer")
	var report = {"ok": failures.is_empty(), "failures": failures, "characters": game.lib.characters.size(), "sounds": game.audio.streams.size(), "music": game.audio.music.size(), "user_dir": OS.get_user_data_dir(), "editor": OS.has_feature("editor")}
	FileAccess.open("user://build-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BUILD CHECK: ", JSON.stringify(report))
	var tree = game.get_tree()
	tree.quit(0 if failures.is_empty() else 1)
