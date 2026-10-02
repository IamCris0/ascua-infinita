extends SceneTree
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.state.paused = true
	var initial: float = game.state.enemy_hp
	game.state.paused = false
	game.arena.clicked.emit()
	check(game.state.enemy_hp < initial, "Arena click is wired to combat")
	game.state.gold = 100
	game.refresh()
	game.upgrade_buttons[1].pressed.emit()
	check(game.state.wisps == 1, "Upgrade button is wired")
	game.toggle_pause()
	check(game.state.paused and game.modal_type == "pause", "Pause opens overlay")
	game.toggle_pause()
	check(game.state.active() and not game.overlay.visible, "Pause resumes")
	game.state.room = 5
	game.state.damage_enemy(100000)
	check(game.modal_type == "relic" and game.overlay.visible, "Relic chooser opens")
	var modal = game.modal_panel.get_child(0)
	for child in modal.get_children():
		if child is Button:
			child.pressed.emit()
			break
	check(game.state.relics.size() == 1 and not game.overlay.visible, "Relic button applies selection")
	game.confirm_retreat()
	check(game.modal_type == "retreat" and game.state.paused, "Retreat requires in-game confirmation")
	game.state.finish_run()
	check(game.modal_type == "camp" and game.state.dead, "Retreat opens permanent progression")
	modal = game.modal_panel.get_child(0)
	var last = modal.get_child(modal.get_child_count() - 1)
	last.pressed.emit()
	check(game.state.active() and game.state.room == 1 and not game.overlay.visible, "Rebirth button starts a new run")
	print("UI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
