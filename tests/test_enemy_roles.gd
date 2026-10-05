extends SceneTree
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_roles.json"
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func encounter(room: int):
	var s = State.new()
	s.restart()
	s.room = room
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.wisps = 0
	return s
func _initialize() -> void:
	var s = encounter(6)
	check(s.enemy_role() == "guardian" and s.enemy_kind() == "sentinel" and s.shield_hits == 4, "Guardian enters with four shield segments")
	var hp = s.enemy_hp
	s.damage_enemy(10)
	check(is_equal_approx(hp - s.enemy_hp, 6.5) and s.shield_hits == 3, "Shield reduces damage and loses one segment")
	s.damage_enemy(10, false, true)
	check(s.shield_hits == 2, "Companions also wear down the shield")
	check(s.save_game(SAVE), "Partial shield saves")
	var restored = State.new()
	check(restored.load_game(SAVE, false) and restored.shield_hits == 2, "Loading cannot refill a shield")
	s.damage_enemy(10)
	hp = s.enemy_hp
	s.damage_enemy(10)
	check(s.shield_hits == 0 and is_equal_approx(hp - s.enemy_hp, 10), "Fourth hit breaks shield and deals full damage")
	s = encounter(6)
	hp = s.enemy_hp
	var burst = s.burst_damage()
	s.burst()
	check(s.shield_hits == 0 and is_equal_approx(hp - s.enemy_hp, burst), "Destello immediately shatters shield without damage reduction")
	s.room = 7
	s.spawn_enemy(false)
	check(s.shield_hits == 0, "Following enemies do not inherit shields")
	for room in [16, 26, 36]:
		s = encounter(room)
		check(s.enemy_role() == "guardian" and s.shield_hits == 4, "Guardian returns across biomes")
	s = encounter(8)
	check(s.enemy_role() == "acolyte" and s.enemy_kind() == "wisp", "Acolyte has its own role and name")
	hp = s.hp
	s.tick(s.attack_interval())
	check(s.charging and s.hp == hp and s.charge_timer == s.CHARGE_TIME, "Acolyte warns before dealing damage")
	s.tick(1)
	s.paused = true
	s.tick(20)
	check(s.charge_timer == 2 and s.hp == hp, "Pause freezes the warning")
	s.paused = false
	check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.charge_timer == 2 and restored.charging, "Channel resumes from its saved warning")
	s.burst()
	check(not s.charging and s.stun_time == 2 and s.hp == hp, "Destello cancels the Acolyte channel")
	s.tick(1)
	check(s.hp == hp and s.stun_time > 0, "Cancelled channel cannot deal a delayed hit")
	s = encounter(8)
	s.tick(s.attack_interval())
	hp = s.hp
	var damage = s.heavy_damage()
	s.tick(s.CHARGE_TIME)
	check(not s.charging and is_equal_approx(hp - s.hp, damage), "Uninterrupted channel resolves once")
	hp = s.hp
	s.tick(0.1)
	check(s.hp == hp, "Channel damage is not repeated on next frame")
	s = encounter(8)
	s.tick(s.attack_interval())
	s.damage_enemy(1e9)
	check(not s.charging and s.charge_timer == 0, "Defeating the Acolyte cancels its channel")
	print("ENEMY ROLES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
