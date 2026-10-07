extends SceneTree
## Forjador Ciego: molten armour that has to be broken by damage in time.
## godot --headless --path . --script tests/test_forge_keeper.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_forge.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 11
	s.restart()
	s.ember_cooldown = 99999
	s.room = 30
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.wisps = 0
	s.hp = 100000
	return s

func raise_armor(s) -> void:
	s.boss_attacks = 2
	s.attack_timer = 0
	s.tick(s.attack_interval())

func _initialize() -> void:
	var s = fresh()
	check(s.is_forge_keeper() and s.enemy_name() == "FORJADOR CIEGO" and s.discoveries.has("enemy:forge"), "The forge has its own boss and collection entry")
	var king = State.new()
	king.restart()
	king.room = 10
	king.spawn_enemy(false)
	check(not king.is_forge_keeper() and king.enemy_name() == "EL REY SIN BRASA" and king.discoveries.has("enemy:king"), "The King still guards the garden")
	check(not s.next_is_heavy() and s.forge_armor == 0, "Opens with ordinary attacks and no armour")
	raise_armor(s)
	check(s.charging and is_equal_approx(s.forge_armor, s.enemy_max * s.FORGE_ARMOR) and s.charge_name() == "CORAZA FUNDIDA", "Every third attack raises molten armour")
	var health = s.enemy_hp
	s.damage_enemy(s.forge_armor * 0.5, false, true)
	check(s.enemy_hp == health and s.charging and s.forge_armor > 0, "Armour absorbs damage before the Forjador's health")
	var attacks = s.boss_attacks
	s.damage_enemy(s.forge_armor + 10, false, false)
	check(not s.charging and s.forge_armor == 0 and s.stun_time == 2.0 and s.boss_attacks == attacks + 1, "Breaking the armour cancels the pour and stuns")
	check(is_equal_approx(s.enemy_hp, health - 10), "Damage beyond the armour reaches the Forjador")
	var hp = s.hp
	s.tick(2.5)
	check(s.hp == hp, "A broken armour never pours")

	s = fresh()
	raise_armor(s)
	hp = s.hp
	var pour = s.enemy_damage() * s.FORGE_POUR
	s.tick(s.CHARGE_TIME)
	check(not s.charging and s.forge_armor == 0 and is_equal_approx(hp - s.hp, pour), "Intact armour pours for x2.4 damage")
	check(not s.next_is_heavy(), "The pattern restarts with ordinary attacks")

	s = fresh()
	raise_armor(s)
	s.burst_cooldown = 0
	var armour = s.forge_armor
	var expected = s.burst_damage() * s.FORGE_BURST
	health = s.enemy_hp
	check(expected < armour and s.burst(), "Destello is available while the armour holds")
	check(s.charging and s.stun_time == 0 and is_equal_approx(s.forge_armor, armour - expected) and s.enemy_hp == health, "Destello cracks the armour x1.5 without cancelling the pour")

	s = fresh()
	s.relics = ["storm", "eye"]
	raise_armor(s)
	s.forge_armor = 1.0
	s.burst_cooldown = 0
	s.burst()
	check(not s.charging and s.stun_time == 2.0 and is_equal_approx(s.burst_cooldown, s.burst_max_cooldown() * 0.75), "Breaking the armour with Destello counts for Tormenta certera")

	s = fresh()
	raise_armor(s)
	s.paused = true
	armour = s.forge_armor
	s.damage_enemy(armour, false, false)
	s.tick(5.0)
	check(s.charging and s.forge_armor == armour, "Pause freezes the armour and its warning")
	s.paused = false
	s.damage_enemy(armour * 0.25, false, true)
	s.tick(1.0)
	var left = s.forge_armor
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Armour can be saved mid-warning")
	check(restored.charging and is_equal_approx(restored.forge_armor, left) and is_equal_approx(restored.charge_timer, s.charge_timer), "Reload keeps the remaining armour and warning")
	var data = s.snapshot()
	data.erase("forge_armor")
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(restored.load_game(SAVE, false) and restored.forge_armor == 0, "Older saves load without inventing armour")
	data.forge_armor = 1e12
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(restored.load_game(SAVE, false) and is_equal_approx(restored.forge_armor, restored.forge_armor_max()), "Inflated armour is clamped to its maximum")
	data.charging = false
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(restored.load_game(SAVE, false) and restored.forge_armor == 0, "Armour cannot exist outside the warning")

	s = fresh()
	raise_armor(s)
	s.spawn_enemy(false)
	check(s.forge_armor == 0 and not s.charging, "A new encounter starts without armour")
	s = fresh()
	raise_armor(s)
	s.finish_run()
	check(s.forge_armor == 0, "Falling clears the armour")

	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	var copy = State.new().preserve_unreadable_save(SAVE)
	check(not copy.is_empty() and FileAccess.get_file_as_string(copy) == "not a save", "An unreadable save is kept aside before being replaced")
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", copy, copy + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("FORGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
