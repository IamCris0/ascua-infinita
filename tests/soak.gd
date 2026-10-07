extends SceneTree
## Plays the real scene for a while with a scripted player: attacks, buys,
## picks relics, uses Destello, catches embers, dies and is reborn.
## Run with a display to exercise drawing code:
## godot --path . --script tests/soak.gd -- --qa
var game
var frames: int = 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("Run with -- --qa to isolate user saves")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	Engine.time_scale = 3.0
	var s = game.state
	var deaths = 0
	var start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 70000 and deaths < 3:
		await process_frame
		frames += 1
		if "--shots" in OS.get_cmdline_user_args() and frames % 150 == 0:
			get_root().get_viewport().get_texture().get_image().save_png("user://soak_%04d.png" % frames)
		if game.modal_type == "relic":
			game.choose_relic(s.offers[randi() % s.offers.size()])
		elif game.modal_type == "route":
			game.choose_journey(s.run_kills % 3)
		elif game.modal_type == "event":
			game.resolve_journey(s.can_accept_encounter())
		elif game.modal_type == "summary":
			game.show_camp()
		elif game.modal_type == "camp":
			for i in range(6):
				game.buy_legacy(i)
			game.rebirth()
			deaths += 1
		elif game.modal_type == "":
			if frames % 2 == 0:
				game.arena.clicked.emit()
			if s.ember_active:
				game.arena.ember_clicked.emit()
			if s.burst_cooldown <= 0 and (not s.is_boss() or s.charging):
				game.try_burst()
			game.set_buy_mode(2 if frames % 120 == 0 else 0)
			for k in [2, 1, 0, 3]:
				if s.gold >= s.price(k):
					game.purchase(k)
					break
	print("SOAK: %d frames, room %d, best %d, runs %d, kills %d" % [frames, s.room, s.best, s.runs, s.total_kills])
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame
	quit()
