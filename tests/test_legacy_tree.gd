extends SceneTree
## Constelación del Legado: nodes, requirements, caps, oaths, effects and saves.
## godot --headless --path . --script tests/test_legacy_tree.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_tree.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func camp(essence: int = 100000):
	var s = State.new()
	s.rng.seed = 5
	s.restart()
	s.ember_cooldown = 99999
	s.finish_run()
	s.essence = essence
	return s

func fight(s) -> void:
	s.restart()
	s.ember_cooldown = 99999
	s.spawn_delay = 0

func _initialize() -> void:
	var s = camp()
	var oaths = []
	for k in range(State.LEGACY.size()):
		if s.is_oath(k):
			oaths.append(k)
	check(State.LEGACY.size() == 14 and oaths == [State.OATH_ECHO, State.OATH_SWARM, State.OATH_LAST_BREATH], "Fourteen nodes with one oath per branch")
	for k in range(State.LEGACY.size()):
		for requirement in State.LEGACY[k].requires:
			check(requirement[0] != k and State.LEGACY[requirement[0]].branch in [State.LEGACY[k].branch, ""], "Requirements come from the branch or the shared row: " + State.LEGACY[k].name)

	# Requirements gate buying only.
	check(not s.legacy_unlocked(6) and not s.buy_legacy(6), "Ojo templado needs Brasa interior 3")
	for i in range(3):
		s.buy_legacy(0)
	check(s.legacy_unlocked(6) and s.buy_legacy(6) and s.buy_legacy(7), "Brasa interior 3 opens both Filo nodes")
	var before = s.essence
	check(s.buy_legacy(State.OATH_ECHO) and s.essence == before - 120 and s.oath == State.OATH_ECHO, "A first oath is sworn when bought")
	check(s.legacy_maxed(State.OATH_ECHO) and not s.buy_legacy(State.OATH_ECHO), "An oath is bought once")
	var owned = State.new()
	owned.legacy[5] = 2
	owned.legacy[1] = 1
	owned.finish_run()
	owned.essence = 1000
	check(not owned.buy_legacy(5) and owned.legacy[5] == 2 and owned.burst_max_cooldown() < 12.0, "Owned Tormenta levels stay active while Corazón eterno is below 3")

	# One active oath, chosen only at the bonfire.
	for k in [2, 2, 2, 9, 10, 11]:
		s.buy_legacy(k)
	check(s.legacy_level(State.OATH_SWARM) == 1 and s.oath == State.OATH_ECHO, "Buying a second oath keeps the sworn one")
	check(s.set_oath(State.OATH_SWARM) and s.oath == State.OATH_SWARM, "Owned oaths can be swapped at the bonfire")
	check(not s.set_oath(State.OATH_LAST_BREATH) and not s.set_oath(3), "Unowned oaths and plain nodes cannot be sworn")
	fight(s)
	check(not s.set_oath(State.OATH_ECHO) and s.oath == State.OATH_SWARM, "The oath cannot change during an expedition")

	# Effects.
	var base = camp()
	fight(base)
	var t = camp()
	t.legacy[6] = 5
	t.legacy[7] = 3
	t.legacy[9] = 2
	t.legacy[10] = 5
	t.legacy[12] = 5
	fight(t)
	check(is_equal_approx(t.critical_chance() - base.critical_chance(), 0.10), "Ojo templado adds 2% critical chance per level")
	check(t.max_combo() == 35 and base.max_combo() == 20, "Cadena larga raises the chain cap to 35")
	check(t.wisps == 3 and base.wisps == 1, "Lucero heredado adds starting companions")
	check(is_equal_approx(t.wisp_interval(), 0.75), "Órbita veloz quickens companion volleys")
	t.wisps = 1
	t.enemy_hp = 1e9
	t.enemy_max = 1e9
	t.tick(0.76)
	check(t.enemy_hp < 1e9, "Companions strike on the quicker interval")
	t.hp = 100
	t.attack_timer = t.attack_interval()
	var raw = t.enemy_damage()
	t.tick(0.01)
	check(is_equal_approx(100 - t.hp, raw * 0.8), "Piel de ceniza reduces damage taken by 4% per level")

	var swarm = camp()
	swarm.legacy[State.OATH_SWARM] = 1
	swarm.set_oath(State.OATH_SWARM)
	fight(swarm)
	var plain = camp()
	fight(plain)
	check(swarm.wisps == 2 and is_equal_approx(swarm.wisp_interval(), 0.75) and is_equal_approx(swarm.click_damage(), plain.click_damage() * 0.9), "Enjambre: one more companion, faster volleys, weaker clicks")

	var echo = camp()
	echo.legacy[State.OATH_ECHO] = 1
	echo.set_oath(State.OATH_ECHO)
	fight(echo)
	echo.enemy_hp = 1e9
	echo.enemy_max = 1e9
	echo.combo = 8
	echo.click_cooldown = 0
	echo.click()
	check(not echo.pending_echo, "Ordinary hits of a chain are not echoes")
	echo.tick(0.3)
	echo.combo_time = 1.5
	echo.click()
	var expected = echo.click_damage() * (1 + 10 * 0.015) * (echo.critical_multiplier() if echo.pending_critical else 1.0) * 3
	check(echo.combo == 10 and echo.pending_echo and is_equal_approx(echo.pending_damage, expected), "Golpe de eco triples the tenth hit of a chain")
	var struck = [false]
	echo.echo_strike.connect(func(): struck[0] = true)
	echo.tick(echo.HIT_DELAY)
	check(struck[0] and not echo.pending_echo, "The echo announces itself when it lands")

	var breath = camp()
	breath.legacy[State.OATH_LAST_BREATH] = 1
	breath.set_oath(State.OATH_LAST_BREATH)
	fight(breath)
	breath.hp = 5
	breath.burst_cooldown = 9
	breath.attack_timer = breath.attack_interval()
	breath.tick(0.01)
	check(not breath.dead and is_equal_approx(breath.hp, breath.max_hp() * 0.3) and breath.burst_cooldown == 0 and breath.fury_time == 12.0 and breath.last_breath_used, "Último aliento saves a lethal blow once with 30% health, Destello and fury")
	check(breath.save_game(SAVE), "Spent last breath can be saved")
	var restored = State.new()
	check(restored.load_game(SAVE, false) and restored.last_breath_used and restored.oath == State.OATH_LAST_BREATH, "Reload keeps the spent last breath and the oath")
	breath.hp = 1
	breath.attack_timer = breath.attack_interval()
	breath.tick(0.01)
	check(breath.dead, "The second lethal blow ends the expedition")
	breath.restart()
	check(not breath.last_breath_used, "A new expedition restores the last breath")

	# Saves from 0.3: six legacy entries and no oath.
	var old = camp().snapshot()
	old.legacy = [3, 2, 3, 2, 4, 2]
	old.erase("oath")
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated = State.new()
	check(migrated.load_game(SAVE, false) and migrated.legacy.size() == 14 and migrated.legacy.slice(0, 6) == [3, 2, 3, 2, 4, 2] and migrated.oath == -1, "0.3 saves keep every level and start without an oath")
	check(not migrated.legacy_unlocked(5) and migrated.legacy_level(5) == 2, "A 0.3 Tormenta stays owned until Corazón eterno reaches 3")
	old.legacy = [3, 2, 3, 2, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0]
	old.oath = State.OATH_ECHO
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(migrated.load_game(SAVE, false) and migrated.oath == -1, "An unowned oath in a save is dropped")
	old.oath = 99
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(not migrated.load_game(SAVE, false) or migrated.oath == -1, "An impossible oath never loads")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	print("TREE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
