extends SceneTree
## Diagnostic: minimum heights of the HUD panels. Not part of the suites.
## godot --headless --path . --script tools/hud_probe.gd -- --qa [--language=en]

func _initialize() -> void:
	run.call_deferred()

func dump(node: Control, depth: int) -> void:
	if depth > 9:
		return
	print("  ".repeat(depth) + "%s %s min=%s" % [node.get_class(), node.name, node.get_combined_minimum_size()])
	for child in node.get_children():
		if child is Control:
			dump(child, depth + 1)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var s = game.state
	s.room = 17
	s.spawn_enemy(false)
	s.relics = ["fang", "eye", "clock", "coin", "storm", "heart", "ash"]
	game.refresh()
	await process_frame
	dump(game.game_root.get_child(1), 0)
	game.queue_free()
	await process_frame
	quit()
