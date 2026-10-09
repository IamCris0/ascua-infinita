extends SceneTree
## Parada, punto débil and the walk between chambers.
## godot --headless --path . --script tests/test_active_combat.gd
const State = preload("res://scripts/run_state.gd")
const Arena = preload("res://scripts/arena.gd")
const SAVE = "user://qa_active_combat.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 21
	s.restart()
	s.spawn_delay = 0
	s.wisps = 0
	s.ember_cooldown = 99999
	return s

## Faces an enemy in `room` with no pending decision.
func face(s, room: int) -> void:
	s.offers.clear()
	s.journey_phase = ""
	s.encounter_kind = ""
	s.room = room
	s.spawn_enemy(false)
	s.spawn_delay = 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(State.SPAWN_DELAY >= 1.0, "Chambers are separated by a walk, not a blink")
	var s = State.new()
	s.restart()
	check(s.spawn_delay == s.SPAWN_DELAY and not s.can_strike(), "The first rival is still walking in")

	# Parada catches a normal blow.
	s = fresh()
	var hp = s.hp
	s.attack_timer = s.attack_interval() - 0.2
	check(is_equal_approx(s.blow_in(), 0.2), "The next blow is announced")
	check(s.parry() and s.parry_window == s.PARRY_WINDOW, "The guard goes up")
	check(not s.parry(), "The guard cannot be raised twice")
	var enemy_hp = s.enemy_hp
	var riposte = s.click_damage() * s.PARRY_RIPOSTE
	s.tick(0.25)
	check(s.hp == hp, "A perfectly parried blow deals no damage")
	check(s.stun_time > 0 and s.total_parries == 1 and s.parry_window == 0, "A perfect parry stuns the enemy and spends the guard")
	check(is_equal_approx(enemy_hp - s.enemy_hp, riposte), "The bearer ripostes after a perfect parry")
	check(s.parry_cooldown <= s.PARRY_RECOVER, "A successful parry recovers quickly")
	check(s.blow_in() < 0, "No blow is coming while the enemy is stunned")

	# A guard raised a little early only blocks half the blow.
	s = fresh()
	hp = s.hp
	s.attack_timer = s.attack_interval() - 0.4
	var blow = s.enemy_damage()
	check(s.parry(), "Guard raised a little early")
	s.tick(0.45)
	check(is_equal_approx(hp - s.hp, blow * s.PARRY_BLOCK), "A late guard blocks half the blow")
	check(s.stun_time == 0 and s.total_parries == 0 and s.parry_cooldown <= s.PARRY_RECOVER, "A block neither stuns nor counts as a parry")

	# A guard raised too early catches nothing and leaves a long recovery.
	s = fresh()
	hp = s.hp
	s.attack_timer = s.attack_interval() - 1.5
	check(s.parry(), "Guard raised early")
	s.tick(1.0)
	check(s.parry_window == 0 and not s.can_parry(), "The guard falls and needs time to recover")
	s.tick(0.6)
	check(s.hp < hp and s.total_parries == 0, "The blow lands after a mistimed guard")
	check(s.parry_cooldown > 0, "Mashing the guard does not cover the next blow")

	# Charged blows only lose half.
	s = fresh()
	face(s, 8)
	s.wisps = 0
	s.charging = true
	s.charge_timer = 0.1
	check(s.blow_in() < 0, "A charge is not a parry cue")
	var expected = s.heavy_damage() * s.PARRY_HEAVY
	hp = s.hp
	check(s.parry(), "Guard against a charged blow")
	s.tick(0.15)
	check(is_equal_approx(hp - s.hp, expected), "A perfectly guarded charge loses half its damage")
	check(s.total_parries == 0 and s.stun_time == 0, "A charge is not cancelled by a parry")
	s = fresh()
	face(s, 8)
	s.wisps = 0
	s.charging = true
	s.charge_timer = 0.4
	expected = s.heavy_damage() * s.PARRY_HEAVY_BLOCK
	hp = s.hp
	s.parry()
	s.tick(0.45)
	check(is_equal_approx(hp - s.hp, expected), "A late guard takes a quarter off a charge")

	# A boss still advances its pattern when its blow is parried.
	s = fresh()
	face(s, 10)
	s.wisps = 0
	var attacks = s.boss_attacks
	hp = s.hp
	var boss_blow = s.enemy_damage()
	s.attack_timer = s.attack_interval() - 0.1
	s.parry()
	s.tick(0.15)
	check(s.boss_attacks == attacks + 1 and s.stun_time > 0, "Parrying a boss blow counts toward its pattern")
	check(is_equal_approx(hp - s.hp, boss_blow * s.PARRY_BOSS), "A boss is stunned by a perfect parry but still lands half its blow")

	# Punto débil.
	s = fresh()
	s.hp = 1e6
	s.tick(s.WEAK_FIRST - 0.1)
	check(not s.weak_active, "The weak point waits a moment into the fight")
	s.tick(0.2)
	check(s.weak_active and is_equal_approx(s.weak_timer, s.WEAK_TIME), "A weak point lights up")
	check(absf(s.weak_pos.x) <= 1 and absf(s.weak_pos.y) <= 1, "The weak point sits on the enemy")
	s.click_cooldown = 0
	check(s.click() and s.weak_active, "An ordinary attack does not reach the weak point")
	check(not s.strike_weak(), "The weak point still needs the click recovery")
	s.click_cooldown = 0
	s.pending_damage = 0
	s.combo = 0
	s.burst_cooldown = 5.0
	var damage = s.click_damage() * (1 + 1 * 0.015) * s.critical_multiplier() * s.WEAK_BONUS
	check(s.strike_weak(), "An aimed click strikes the weak point")
	check(s.pending_critical and is_equal_approx(s.pending_damage, damage), "The weak point is a sure critical with its bonus")
	check(is_equal_approx(s.burst_cooldown, 5.0 - s.WEAK_RECHARGE), "Striking the weak point speeds Destello")
	check(not s.weak_active and s.total_weak == 1 and s.weak_cooldown >= 6, "The weak point is spent until the next one")
	s.click_cooldown = 0
	check(not s.strike_weak(), "A spent weak point cannot be struck again")

	s = fresh()
	s.hp = 1e6
	s.tick(s.WEAK_FIRST + 0.1)
	s.tick(s.WEAK_TIME)
	check(not s.weak_active, "An ignored weak point fades")
	s.tick(10.1)
	check(s.weak_active, "Another weak point follows within ten seconds")
	s.damage_enemy(1e12)
	check(not s.weak_active and s.weak_cooldown == s.WEAK_FIRST, "A new rival starts without a weak point")

	# Persistence and older saves.
	s = fresh()
	s.hp = 1e6
	s.tick(s.WEAK_FIRST + 0.5)
	s.attack_timer = 0
	s.parry()
	s.tick(0.1)
	s.total_parries = 7
	s.total_weak = 3
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Save with a lit weak point and a raised guard")
	check(restored.weak_active and is_equal_approx(restored.weak_timer, s.weak_timer) and restored.weak_pos.is_equal_approx(s.weak_pos), "The weak point survives a reload")
	check(is_equal_approx(restored.parry_window, s.parry_window) and is_equal_approx(restored.parry_cooldown, s.parry_cooldown), "The guard survives a reload")
	check(restored.total_parries == 7 and restored.total_weak == 3, "Parry and weak point counters are kept")
	var data: Dictionary = s.snapshot()
	for key in ["parry_window", "parry_cooldown", "weak_active", "weak_timer", "weak_cooldown", "weak_pos", "total_parries", "total_weak"]:
		data.erase(key)
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and not restored.weak_active and restored.total_parries == 0 and restored.weak_cooldown == restored.WEAK_FIRST, "Older saves load without the new combat fields")
	data = s.snapshot()
	data.weak_pos = [3, 0]
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(not State.new().load_game(SAVE, false), "A weak point off the enemy is rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + ".bak"))

	# Achievements.
	s = fresh()
	s.total_parries = 24
	s.attack_timer = s.attack_interval() - 0.1
	s.parry()
	s.tick(0.15)
	check(s.achievements.has("parry"), "Twenty-five parries earn Guardia perfecta")
	s = fresh()
	s.total_weak = 49
	s.weak_active = true
	s.weak_timer = 1.0
	s.strike_weak()
	check(s.achievements.has("weak"), "Fifty weak points earn Ojo certero")

	# Stage: aimed clicks and the guard.
	s = fresh()
	var arena = Arena.new()
	arena.state = s
	arena.size = Vector2(760, 590)
	root.add_child(arena)
	arena.set_process(false)
	for actor in [arena.hero, arena.enemy, arena.corpse]:
		actor.set_process(false)
	var heard = []
	arena.weak_clicked.connect(func(): heard.append("weak"))
	arena.clicked.connect(func(): heard.append("click"))
	arena.guard_clicked.connect(func(): heard.append("guard"))
	s.weak_active = true
	s.weak_timer = 2.0
	s.weak_pos = Vector2(0.4, -0.3)
	arena._gui_input(mouse(arena.stage_to_screen(arena.weak_stage_pos()), MOUSE_BUTTON_LEFT))
	arena._gui_input(mouse(arena.stage_to_screen(arena.weak_stage_pos()) + Vector2(140, 0), MOUSE_BUTTON_LEFT))
	arena._gui_input(mouse(Vector2(30, 30), MOUSE_BUTTON_RIGHT))
	check(heard == ["weak", "click", "guard"], "Aimed clicks reach the weak point; others attack; right click guards: %s" % [heard])
	arena.on_parried(true)
	check(arena.numbers.any(func(n): return n.text == "¡PARADA!") and arena.enemy.playing("hurt"), "A parry staggers the enemy on stage")
	s.restart()
	arena._process(0.016)
	check(arena.travelling() and arena.hero.playing("walk"), "The bearer walks on between chambers")
	s.spawn_delay = 0
	arena._process(0.016)
	check(not arena.travelling() and arena.hero.playing("idle"), "The bearer stops to fight")
	arena.queue_free()
	await process_frame
	load("res://scripts/art_library.gd").release()
	print("ACTIVE COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func mouse(at: Vector2, button: int) -> InputEventMouseButton:
	var e = InputEventMouseButton.new()
	e.position = at
	e.button_index = button
	e.pressed = true
	return e
