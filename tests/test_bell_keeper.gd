extends SceneTree
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_bell.json"
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
	s.room = 20
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.wisps = 0
	s.armor = 100
	s.hp = s.max_hp()
	return s
func start_silence(s):
	s.boss_attacks = 1
	s.tick(s.attack_interval())
func _initialize():
	var s = fresh()
	check(s.is_bell_keeper() and s.enemy_name() == "CAMPANERA VACÍA", "Crypt boss has its own identity")
	check(not s.next_is_heavy(), "Opens with an ordinary attack")
	s.tick(s.attack_interval())
	check(s.boss_attacks == 1 and not s.charging, "First attack advances to silence pattern")
	s.tick(s.attack_interval())
	check(s.charging and s.bell_silence() and s.bell_resonance == 0, "Silence starts with a full warning and zero resonance")
	var health = s.enemy_max * 0.5
	s.enemy_hp = health
	s.manual_rest = s.ECHO_REST
	s.tick(0.5)
	check(not s.echo_healing() and s.enemy_hp == health, "Resting during Silence never heals the Campanera")
	s.wisps = 1
	s.tick(1)
	check(s.bell_resonance == 0, "Companions never provoke silence")
	s.click()
	check(s.bell_resonance == 1 and not s.click() and s.bell_resonance == 1, "Only accepted manual attacks increase resonance")
	s.tick(0.31)
	s.click()
	s.tick(0.31)
	s.click()
	s.tick(0.31)
	s.click()
	check(s.bell_resonance == 3, "Resonance is capped")
	var timer = s.charge_timer
	s.paused = true
	s.tick(10)
	check(s.charge_timer == timer and s.bell_resonance == 3, "Pause freezes resonance and warning")
	s.paused = false
	check(s.save_game(SAVE), "Save mid-silence")
	var restored = State.new()
	check(restored.load_game(SAVE, false) and restored.bell_silence() and restored.bell_resonance == 3 and is_equal_approx(restored.charge_timer, timer), "Reload preserves exact boss phase")
	var hp = s.hp
	var damage = s.heavy_damage()
	s.tick(timer + 0.01)
	check(is_equal_approx(hp - s.hp, damage) and s.boss_attacks == 2 and s.bell_resonance == 0, "Silence resolves once and clears resonance")
	s = fresh()
	start_silence(s)
	var quiet = s.heavy_damage()
	s.click()
	check(s.heavy_damage() > quiet, "Withholding manual attacks reduces incoming damage")
	s.burst()
	check(not s.charging and s.boss_attacks == 2 and s.bell_resonance == 0 and s.stun_time > 0, "Optional Destello cancels silence")
	s = fresh()
	s.boss_attacks = 3
	s.tick(s.attack_interval())
	check(s.charging and not s.bell_silence() and s.charge_name() == "TOQUE FÚNEBRE", "Second channel is Funeral Toll")
	check(is_equal_approx(s.heavy_damage(), s.enemy_damage() * 2.4), "Toll has its own damage multiplier")
	s.burst()
	check(not s.charging and s.boss_attacks == 4, "Interrupt advances to next pattern")
	s = fresh()
	start_silence(s)
	s.click()
	s.damage_enemy(1e12)
	check(not s.charging and s.bell_resonance == 0 and s.total_bosses == 1 and s.room == 21, "Boss death clears mechanics and grants normal progression")
	for room in [10, 30, 40]:
		s.room = room
		check(not s.is_bell_keeper(), "Other biomes retain their boss")
	s.room = 50
	check(s.is_bell_keeper(), "Campanera returns in later crypt cycles")
	print("BELL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
