extends SceneTree
const State = preload("res://scripts/run_state.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize():
	run.call_deferred()
func run():
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("Run with -- --qa to isolate user saves")
		quit(1)
		return
	var s = State.new()
	s.restart()
	check(s.discoveries == ["enemy:slime"], "First encounter reveals only its own entry")
	check(s.collection_catalog().size() == 28, "Catalog includes enemies, relics, synergies and the arsenal")
	s.spawn_enemy(false)
	check(s.discoveries.size() == 1, "Repeated encounters are deduplicated")
	s.offers = [0]
	s.choose_relic(0)
	check(s.discoveries.has("relic:fang") and not s.discoveries.has("synergy:precision"), "Relic discovery does not invent a synergy")
	s.offers = [2]
	s.choose_relic(2)
	check(s.discoveries.has("synergy:precision"), "Completing the pair discovers its synergy")
	s.room = 20
	s.spawn_enemy(false)
	check(s.discoveries.has("enemy:bell") and not s.discoveries.has("enemy:king"), "Distinct bosses have distinct discoveries")
	var records = s.discoveries.duplicate()
	s.restart()
	check(s.discoveries == records and s.relics.is_empty(), "Rebirth keeps the collection but clears equipped relics")
	check(s.save_game("user://qa_collection.json"), "Collection saves")
	var loaded = State.new()
	check(loaded.load_game("user://qa_collection.json", false) and loaded.discoveries == records, "Collection survives reloading")
	var old = s.snapshot()
	old.erase("discoveries")
	old.relics = ["clock", "coin"]
	var file = FileAccess.open("user://qa_collection_old.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(loaded.load_game("user://qa_collection_old.json", false), "Older save migrates")
	check(loaded.discoveries.has("relic:clock") and loaded.discoveries.has("synergy:chorus") and not loaded.discoveries.has("enemy:bell"), "Migration infers only present evidence")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.show_collection("pause")
	check(game.modal_type == "collection" and game.state.paused, "Collection pauses combat")
	var names: Array = game.modal_buttons().map(func(b): return b.text)
	check(names.has("Enemigos") and names.has("Reliquias") and names.has("Sinergias") and names.has("Arsenal"), "All catalog categories are navigable")
	check(names.any(func(n): return n.begins_with("Logros")) and names.any(func(n): return n.begins_with("Retos")) and names.has("Registro") and names.has("Estadísticas"), "Retos, achievements, the log and statistics have their own tabs")
	game.state.unlock("first_kill")
	game.show_collection("pause", "Logros")
	var texts: Array = []
	for label in game.modal_panel.find_children("*", "Label", true, false):
		texts.append(label.text)
	check(texts.any(func(t): return t.begins_with("1 de %d logros" % game.state.ACHIEVEMENTS.size())) and texts.has("★  Primera brasa"), "The achievements tab lists progress and unlocked goals")
	game.show_collection("pause", "Registro")
	game.show_collection("pause", "Reliquias")
	var hp = game.state.hp
	game.state.tick(20)
	check(game.state.hp == hp, "Browsing does not advance combat")
	game._return_from("pause")
	check(game.modal_type == "pause" and game.state.paused, "Back returns to pause menu")
	game.close_modal()
	check(not game.state.paused, "Continue resumes combat")
	game.queue_free()
	await process_frame
	print("COLLECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
