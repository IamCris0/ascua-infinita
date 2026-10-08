extends SceneTree
## Eclipse levels, achievements and the expedition log.
## godot --headless --path . --script tests/test_eclipse.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_eclipse.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 13
	s.restart()
	s.ember_cooldown = 99999
	return s

## Faces an enemy in `room` with no pending relic or route decision.
func face(s, room: int) -> void:
	s.offers.clear()
	s.journey_phase = ""
	s.encounter_kind = ""
	s.room = room
	s.spawn_enemy(false)
	s.spawn_delay = 0

func beat_boss(s, room: int) -> void:
	face(s, room)
	s.damage_enemy(1e12)

func _initialize() -> void:
	var s = fresh()
	check(s.eclipse == 0 and s.eclipse_unlocked == 0 and not s.set_eclipse(1), "Eclipse starts locked")
	beat_boss(s, 10)
	check(s.eclipse_unlocked == 0, "Only a cycle boss unlocks Eclipse")
	beat_boss(s, 30)
	check(s.eclipse_unlocked == 1 and not s.achievements.has("eclipse"), "Clearing room 30 unlocks Eclipse 1")
	beat_boss(s, 60)
	check(s.eclipse_unlocked == 1, "Clearing more cycles below the top level unlocks nothing new")
	check(not s.set_eclipse(1), "The level cannot change during an expedition")
	s.finish_run()
	check(s.set_eclipse(1) and s.eclipse == 1 and not s.set_eclipse(2), "Unlocked levels are chosen at the bonfire")
	s.restart()
	beat_boss(s, 30)
	check(s.eclipse_unlocked == 2 and s.achievements.has("eclipse"), "Clearing a cycle at the top level opens the next and earns the achievement")
	for i in range(6):
		s.finish_run()
		s.set_eclipse(s.eclipse_unlocked)
		s.restart()
		beat_boss(s, 30)
	check(s.eclipse_unlocked == 5 and s.eclipse == 5, "Each level unlocks the next, up to Eclipse 5")

	# Cumulative rules.
	var base = fresh()
	var e = fresh()
	e.eclipse = 5
	base.room = 20
	e.room = 20
	base.spawn_enemy(false)
	e.spawn_enemy(false)
	check(is_equal_approx(e.enemy_damage(), base.enemy_damage() * 1.15), "Eclipse 2: enemies hit 15% harder")
	check(is_equal_approx(e.burst_max_cooldown(), base.burst_max_cooldown() * 1.2), "Eclipse 3: Destello recharges 20% slower")
	check(is_equal_approx(e.enemy_max, base.enemy_max * 1.25), "Eclipse 4: bosses have 25% more health")
	check(e.rest_heal() == 0.1 and e.shrine_heal() == 0.225 and base.rest_heal() == 0.2, "Eclipse 5: rests and shrines heal half")
	var elites = [0, 0]
	for i in range(2):
		var r = fresh()
		r.eclipse = i
		r.room = 7
		for n in range(3000):
			r.spawn_enemy(true)
			elites[i] += 1 if r.enemy_elite else 0
	check(elites[0] < 450 and elites[1] > 600, "Eclipse 1: elites twice as often (%d vs %d of 3000)" % elites)

	# Banking and the log.
	var b = fresh()
	b.eclipse = 2
	b.run_essence = 50
	b.room = 23
	b.run_kills = 40
	b.run_time = 425
	check(b.banked_preview() == 70, "Eclipse 2 previews +40% ascuas")
	var before = b.essence
	b.finish_run()
	check(b.essence == before + 70 and b.last_banked == 70, "Eclipse 2 banks +40% ascuas")
	var entry: Dictionary = b.history[0]
	check(entry.room == 23 and entry.kills == 40 and entry.time == 425 and entry.eclipse == 2 and entry.banked == 70 and entry.oath == -1, "The log records the expedition")
	for i in range(12):
		b.restart()
		b.room = 2 + i
		b.finish_run()
	check(b.history.size() == State.HISTORY_SIZE and b.history[0].room == 13, "The log keeps the latest expeditions, newest first")

	# Achievements.
	var a = fresh()
	var announced = []
	a.achievement_unlocked.connect(func(id): announced.append(id))
	a.spawn_delay = 0
	a.damage_enemy(1e12)
	check(a.achievements.has("first_kill") and announced == ["first_kill"], "The first victory is an achievement, announced once")
	a.damage_enemy(1e12)
	check(announced.size() == 1, "Achievements are not announced twice")
	face(a, 10)
	a.click_cooldown = 0
	a.click()
	a.tick(a.HIT_DELAY)
	a.damage_enemy(1e12)
	check(a.achievements.has("king") and not a.achievements.has("idle_boss"), "Beating the King counts; clicking spoils the idle victory")
	beat_boss(a, 20)
	check(a.achievements.has("bell") and a.achievements.has("idle_boss"), "A boss beaten without clicks earns the idle achievement")
	face(a, 30)
	for i in range(5):
		a.boss_attacks = 2
		a.attack_timer = a.attack_interval()
		a.tick(0.01)
		a.damage_enemy(a.forge_armor + 1)
		a.stun_time = 0
	check(a.total_armor_breaks == 5 and a.achievements.has("armor"), "Five broken armours earn Rompecorazas")
	face(a, 10)
	for i in range(10):
		a.charging = true
		a.burst_cooldown = 0
		a.burst()
	check(a.total_interrupts == 10 and a.achievements.has("interrupts"), "Ten interruptions earn Mano rápida")
	a.total_embers = 24
	a.ember_active = true
	a.collect_ember()
	check(a.achievements.has("embers"), "The 25th ember earns Cazador de ascuas")
	a.relics = ["fang", "eye"]
	a.remember_relics()
	check(a.achievements.has("synergy"), "A completed pair earns Afinidad")
	for entry_c in a.collection_catalog():
		a.remember(entry_c.id)
	check(a.achievements.has("collection"), "A full collection earns its achievement")
	a.finish_run()
	a.essence = 10000
	for k in [0, 0, 0, 6, 7, 8]:
		a.buy_legacy(k)
	check(a.achievements.has("oath"), "Buying an oath earns Juramentado")

	# Saves.
	a.eclipse_unlocked = 3
	a.set_eclipse(2)
	var restored = State.new()
	check(a.save_game(SAVE) and restored.load_game(SAVE, false), "Eclipse, achievements and the log save")
	check(restored.eclipse == 2 and restored.eclipse_unlocked == 3 and restored.achievements == a.achievements and restored.history.size() == a.history.size() and restored.total_interrupts == 10, "Everything returns after a reload")
	var data = a.snapshot()
	for key in ["eclipse", "eclipse_unlocked", "total_interrupts", "total_armor_breaks", "achievements", "history"]:
		data.erase(key)
	_write(data)
	check(restored.load_game(SAVE, false) and restored.eclipse == 0 and restored.history.is_empty() and restored.achievements.has("first_kill") and restored.achievements.has("oath"), "Older saves start at Eclipse 0 and earn what their counters prove")
	data = a.snapshot()
	data.achievements = ["made_up"]
	_write(data)
	check(not restored.load_game(SAVE, false), "Unknown achievements are rejected")
	data = a.snapshot()
	data.history = [{"room": "x"}]
	_write(data)
	check(not restored.load_game(SAVE, false), "A malformed log is rejected")
	data = a.snapshot()
	data.eclipse = 4
	data.eclipse_unlocked = 9
	_write(data)
	check(restored.load_game(SAVE, false) and restored.eclipse_unlocked == 5 and restored.eclipse == 4, "Eclipse values are clamped to what exists")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	print("ECLIPSE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _write(data: Dictionary) -> void:
	for suffix in [".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
