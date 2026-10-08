extends SceneTree
## Capture the Forjador's molten armour in the real interface without user saves.
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
	var s = game.state
	s.room = 30
	s.spawn_enemy(false)
	s.spawn_delay = 0
	arena.sync_enemy(false)
	arena.banner = {}
	arena.bg_index = s.biome()
	arena.bg_prev = arena.bg_index
	arena.bg_fade = 0
	s.boss_attacks = 2
	s.charging = true
	s.charge_timer = 1.6
	s.forge_armor = s.forge_armor_max() * 0.55
	arena._process(0)
	arena.hero._process(0)
	arena.enemy._process(0)
	game.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/forjador.png")
	game.queue_free()
	await process_frame
	quit()
