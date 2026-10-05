extends SceneTree
## Capture both provisional enemy roles in the real interface without user saves.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("Run with -- --qa to isolate user saves")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var arena = game.arena
	arena.set_process(false)
	arena.hero.set_process(false)
	arena.enemy.set_process(false)
	arena.corpse.set_process(false)
	for room in [6, 8]:
		game.state.room = room
		game.state.spawn_enemy(false)
		game.state.spawn_delay = 0
		arena.sync_enemy(false)
		arena.banner = {}
		if room == 8:
			game.state.charging = true
			game.state.charge_timer = 2
		arena._process(0)
		arena.hero._process(0)
		arena.enemy._process(0)
		game.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/enemy-%d.png" % room)
	game.queue_free()
	await process_frame
	quit()
