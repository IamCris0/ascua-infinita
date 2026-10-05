extends SceneTree
const State = preload("res://scripts/run_state.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(pair: Array):
	var s = State.new()
	s.restart()
	s.spawn_delay = 0
	s.relics = pair.duplicate()
	s.enemy_hp = 100000
	return s
func _initialize():
	var s = fresh(["fang"])
	check(not s.has_synergy("precision"), "One relic alone does not activate a pair")
	s.relics.append("eye")
	check(s.has_synergy("precision"), "Pair activates its synergy")
	s.burst_cooldown = 5
	s.click()
	s.pending_critical = true
	s.tick(s.HIT_DELAY)
	check(is_equal_approx(s.burst_cooldown, 4.45), "Manual critical contact grants one cooldown reduction")
	s.burst_cooldown = 5
	s.damage_enemy(10, true, true)
	check(s.burst_cooldown == 5, "Automatic critical cannot trigger manual synergy")
	s = fresh(["fang", "eye", "fang", "eye"])
	s.burst_cooldown = 0.2
	s.click()
	s.pending_critical = true
	s.tick(s.HIT_DELAY)
	check(s.burst_cooldown == 0, "Cooldown never becomes negative")
	s = fresh(["clock", "coin"])
	var base = s.auto_damage()
	s.tick(2)
	check(is_equal_approx(s.auto_damage(), base * 1.3), "Rest activates chorus")
	s.burst()
	check(is_equal_approx(s.auto_damage(), base * 1.3), "Destello preserves chorus")
	s.click()
	check(is_equal_approx(s.auto_damage(), base), "Accepted manual attack ends chorus")
	s.paused = true
	s.tick(20)
	check(s.manual_rest == 0, "Pause cannot charge chorus")
	s = fresh(["storm", "eye"])
	s.burst()
	check(is_equal_approx(s.burst_cooldown, s.burst_max_cooldown()), "Ordinary burst does not gain interruption bonus")
	s.burst_cooldown = 0
	s.charging = true
	s.burst()
	check(is_equal_approx(s.burst_cooldown, s.burst_max_cooldown() * 0.75), "Interrupt rewards correct timing")
	s = fresh(["heart", "ash"])
	s.damage_enemy(1e12)
	check(s.shelter_ready, "Victory grants one defensive charge")
	var hp = s.hp
	s._hit_hero(20, false)
	check(is_equal_approx(hp - s.hp, 12) and not s.shelter_ready, "Shelter reduces and consumes exactly one hit")
	hp = s.hp
	s._hit_hero(20, false)
	check(is_equal_approx(hp - s.hp, 20), "Following hits are not protected")
	s.shelter_ready = true
	s.manual_rest = 1.2
	check(s.save_game("user://qa_synergy.json"), "Synergy state saves")
	var restored = State.new()
	check(restored.load_game("user://qa_synergy.json", false) and restored.shelter_ready and is_equal_approx(restored.manual_rest, 1.2), "Save preserves preparation and protection")
	s.restart()
	check(not s.shelter_ready and s.manual_rest == 0 and not s.has_synergy("shelter"), "Rebirth clears temporary synergies")
	print("SYNERGIES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
