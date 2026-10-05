extends SceneTree
const State = preload("res://scripts/run_state.gd")
const Arena = preload("res://scripts/arena.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh():
	var s = State.new()
	s.restart()
	s.spawn_delay = 0
	s.wisps = 0
	return s
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var s = fresh()
	var initial = s.enemy_hp
	check(s.click() and s.enemy_hp == initial, "Anticipation does not deal premature damage")
	var damage = s.pending_damage
	s.tick(0.1)
	check(s.enemy_hp == initial, "Damage waits for contact")
	s.paused = true
	s.tick(10)
	check(s.enemy_hp == initial and is_equal_approx(s.pending_hit, 0.05), "Pause freezes pending contact")
	s.paused = false
	check(s.save_game("user://timing.json"), "Save mid-swing")
	var restored = State.new()
	check(restored.load_game("user://timing.json", false), "Restore mid-swing")
	s.tick(0.051)
	restored.tick(0.051)
	check(is_equal_approx(s.enemy_hp, initial - damage) and is_equal_approx(s.enemy_hp, restored.enemy_hp), "Restored swing lands exactly once")
	check(not s.click(), "Recovery retains original click cadence")
	s.tick(0.15)
	check(s.click(), "Next swing available after 0.3 seconds")
	s.damage_enemy(1e9)
	check(s.pending_damage == 0, "Target death cancels pending swing")
	s.spawn_delay = 0
	initial = s.enemy_hp
	s.tick(0.2)
	check(s.enemy_hp == initial, "Previous swing cannot hit the next target")
	s = fresh()
	s.enemy_hp = 1
	var order = []
	s.burst_released.connect(func(_interrupted): order.append("visual"))
	s.struck.connect(func(_damage, _critical, _automatic): order.append("impact"))
	s.enemy_defeated.connect(func(_kind, _elite, _boss): order.append("death"))
	s.burst()
	check(order == ["visual", "impact", "death"], "Burst visuals bind to the defeated target before spawning")
	s = fresh()
	var arena = Arena.new()
	arena.state = s
	arena.size = Vector2(760, 590)
	root.add_child(arena)
	arena.set_process(false)
	arena.hero.set_process(false)
	arena.enemy.set_process(false)
	arena.corpse.set_process(false)
	s.attack_started.connect(arena.on_attack_started)
	s.struck.connect(arena.on_struck)
	s.click()
	check(arena.hero.playing("attack") and arena.effects.is_empty(), "Animation starts before impact effect")
	s.tick(s.HIT_DELAY)
	check(is_equal_approx(arena.hero.anim_time, s.HIT_DELAY) and not arena.effects.is_empty(), "Contact pose and impact share the damage event")
	s.paused = true
	arena._process(0.1)
	var pose = arena.hero.anim_time
	arena.hero._process(0.5)
	check(arena.hero.anim_time == pose, "Paused combat freezes actor pose")
	s.paused = false
	s.wisps = 1
	s.auto_timer = 0.8
	arena._process(0.01)
	check(not arena.projectiles.is_empty(), "Companion projectile travels before damage")
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	arena.sync_enemy(false)
	s.charging = true
	s.charge_timer = 0.3
	arena._process(0.01)
	check(arena.heavy_launched, "Boss projectile launches before charged impact")
	arena.on_burst(true)
	check(arena.projectiles.all(func(p): return not p.get("fire", false)), "Interrupt removes cancelled boss projectile")
	arena.queue_free()
	await process_frame
	load("res://scripts/art_library.gd").release()
	print("TIMING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
