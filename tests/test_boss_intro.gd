extends SceneTree
## Boss entrances: full on the first meeting, brief afterwards, skippable,
## holding combat on both sides and surviving a reload.
## godot --headless --path . --script tests/test_boss_intro.gd
const State = preload("res://scripts/run_state.gd")
const Arena = preload("res://scripts/arena.gd")
const SAVE = "user://qa_intro.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh(room: int):
	var s = State.new()
	s.rng.seed = 3
	s.restart()
	s.ember_cooldown = 99999
	s.room = room
	s.spawn_enemy(false)
	return s

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var s = fresh(1)
	for room in [10, 20, 30]:
		s.room = room
		s.spawn_enemy(false)
		check(s.spawn_delay == s.BOSS_INTRO_FULL, "The first meeting is a full entrance: " + s.enemy_id())
		s.spawn_enemy(false)
		check(s.spawn_delay == s.BOSS_INTRO, "Later meetings are brief: " + s.enemy_id())
	s.room = 9
	s.spawn_enemy(false)
	check(s.spawn_delay == s.SPAWN_DELAY and not s.skip_intro(), "Ordinary enemies keep their short arrival and cannot be skipped")

	var t = fresh(30)
	t.wisps = 3
	var hp = t.hp
	var health = t.enemy_hp
	t.click_cooldown = 0
	t.burst_cooldown = 0
	check(not t.click() and not t.burst(), "No attacks during an entrance")
	t.tick(2.0)
	check(t.hp == hp and t.enemy_hp == health and t.in_boss_intro(), "The entrance holds both sides")
	check(t.skip_intro() and is_equal_approx(t.spawn_delay, t.INTRO_SKIP_LEFT) and not t.skip_intro(), "Skipping leaves a short moment, once")
	t.tick(t.INTRO_SKIP_LEFT + 0.01)
	check(not t.in_boss_intro() and t.can_strike(), "Combat starts after a skipped entrance")

	var u = fresh(20)
	u.tick(0.5)
	var restored = State.new()
	check(u.save_game(SAVE) and restored.load_game(SAVE, false) and is_equal_approx(restored.spawn_delay, u.BOSS_INTRO_FULL - 0.5), "A full entrance survives a reload")
	u.paused = true
	check(not u.skip_intro(), "A paused entrance cannot be skipped")

	# Presentation on the stage.
	var a = fresh(30)
	var arena = Arena.new()
	arena.state = a
	arena.size = Vector2(760, 590)
	root.add_child(arena)
	await process_frame
	arena.banner = {}
	arena.sync_enemy(true)
	check(arena.intro_full and arena.banner.is_empty() and arena.letterbox() == 0.0, "A first meeting starts sliding its bars in and draws its own card")
	a.spawn_delay = a.BOSS_INTRO_FULL - 2.2
	arena._process(0.016)
	var base: float = arena.stage.get_meta("scale")
	var origin: Vector2 = arena.stage.get_meta("origin")
	check(arena.intro_zoom() > 1.1 and arena.letterbox() == 1.0 and not arena.enemy.has_meta("walk_in"), "Mid entrance: full bars, a closer look and the boss has arrived")
	check(arena.stage_to_screen(arena.enemy_center()).distance_to(origin + arena.enemy_center() * base) < 4.0, "The closer look keeps the boss in place on screen")
	arena.reduced_motion = true
	arena._process(0.0)
	check(arena.intro_zoom() == 1.0 and arena.letterbox() == 1.0, "Reduced motion keeps the bars without zoom")
	arena.reduced_motion = false
	a.spawn_delay = 0
	arena._process(0.016)
	check(arena.intro_zoom() == 1.0 and arena.letterbox() == 0.0 and is_equal_approx(arena.stage.scale.x, base), "After the entrance the stage returns to its framing")
	a.spawn_enemy(false)
	arena.sync_enemy(true)
	check(not arena.intro_full and not arena.banner.is_empty(), "A brief entrance keeps the name banner")
	arena.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	print("INTRO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
