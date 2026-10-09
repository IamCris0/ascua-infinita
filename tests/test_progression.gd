extends SceneTree
## Rules of the expedition, independent of the interface.
## godot --headless --path . --script tests/test_progression.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_progression.json"
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh() -> Object:
	var s = State.new()
	s.rng.seed = 7
	s.restart()
	s.ember_cooldown = 99999
	return s

func test_legacy_cap() -> void:
	var s = fresh()
	s.dead = true
	s.essence = 1000
	s.legacy[1] = 3
	s.legacy[5] = 9
	var cooldown = s.burst_max_cooldown()
	check(not s.legacy_maxed(5) and s.buy_legacy(5) and s.legacy[5] == 10 and s.burst_max_cooldown() < cooldown, "The final storm legacy level improves the cooldown")
	var bank = s.essence
	check(s.legacy_maxed(5) and not s.buy_legacy(5) and s.essence == bank and s.legacy[5] == 10, "A maxed storm legacy cannot consume ascuas")
	s.legacy[5] = 13
	check(s.save_game(SAVE), "Previously purchased legacy levels can be saved")
	var restored = State.new()
	check(restored.load_game(SAVE, false) and restored.legacy[5] == 13 and restored.essence == bank, "Existing legacy levels above the cap are preserved without a refund")
	check(restored.legacy_maxed(5) and not restored.buy_legacy(5) and restored.essence == bank, "Old over-cap upgrades cannot be purchased again")
	check(not s.legacy_maxed(0) and s.buy_legacy(0), "Other legacy upgrades remain available")

func test_records() -> void:
	var s = fresh()
	s.best = 20
	s.runs = 3
	s.restart()
	s.room = 20
	check(not s.is_record(), "Tying the previous best is not a record")
	s.room = 21
	s.best = 21
	check(s.is_record(), "Passing the previous best is a record")
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.run_start_best == 20 and restored.is_record(), "A resumed expedition remembers the best it started from")

func test_combat_persistence() -> void:
	var s = fresh()
	s.room = 3
	s.ember_cooldown = 0.01
	s.tick(0.1)
	var spawned = State.new()
	check(s.ember_active and s.save_game(SAVE) and spawned.load_game(SAVE, false) and spawned.ember_active, "A naturally spawned ember never writes a negative cooldown to the save")
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.wisps = 1
	s.enemy_hp = s.enemy_max * 0.75
	s.boss_attacks = 2
	s.charging = true
	s.charge_timer = 0.2
	s.auto_timer = 0.9
	s.click_cooldown = 0.05
	s.combo = 6
	s.combo_time = 1.1
	s.manual_rest = 0.5
	s.fury_time = 9.0
	s.ember_active = true
	s.ember_timer = 7.0
	s.ember_pos = Vector2(0.32, 0.27)
	check(s.save_game(SAVE), "Combat phase can be saved")
	var restored = State.new()
	check(restored.load_game(SAVE, false), "Combat phase can be restored")
	check(restored.charging and is_equal_approx(restored.charge_timer, 0.2) and restored.boss_attacks == 2, "Boss charge resumes with its remaining warning time")
	check(restored.fury_time == 9 and restored.ember_active and restored.ember_timer == 7 and restored.ember_pos.is_equal_approx(s.ember_pos), "Fury and the visible ember keep their remaining life and position")
	check(is_equal_approx(restored.auto_timer, 0.9) and is_equal_approx(restored.click_cooldown, 0.05) and restored.combo == 6 and is_equal_approx(restored.combo_time, 1.1), "Click cadence, combo and automatic attacks resume at the same point")
	s.tick(0.25)
	restored.tick(0.25)
	check(restored.hp == s.hp and restored.hp < restored.max_hp() and restored.boss_attacks == 3 and not restored.charging, "Reloading cannot postpone a charged boss hit")
	check(is_equal_approx(restored.enemy_hp, s.enemy_hp) and is_equal_approx(restored.fury_time, 8.75) and is_equal_approx(restored.ember_timer, 6.75), "Reloaded combat advances attacks and rewards identically")
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "A finished charge leaves a valid save")
	s.spawn_enemy(false)
	s.spawn_delay = 1.2
	check(s.save_game(SAVE) and restored.load_game(SAVE, false) and not restored.click() and is_equal_approx(restored.spawn_delay, 1.2), "Reloading preserves the boss entrance delay")
	s.spawn_delay = 0
	s.stun_time = 0.8
	s.attack_timer = 0.9
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "A stunned boss can be restored")
	restored.tick(0.2)
	check(is_equal_approx(restored.stun_time, 0.6) and is_equal_approx(restored.attack_timer, 0.9), "The remaining stun still prevents the next enemy attack")
	restored.ember_timer = 0.1
	restored.tick(0.2)
	check(not restored.ember_active and restored.save_game(SAVE) and s.load_game(SAVE, false), "An expired ember leaves a valid save")
	# Early version 2 saves did not contain these optional combat fields.
	var old = s.snapshot()
	for key in State.COMBAT_DEFAULTS:
		old.erase(key)
	old.erase("ember_pos")
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(restored.load_game(SAVE, false) and not restored.charging and not restored.ember_active and restored.fury_time == 0 and restored.spawn_delay == 0 and restored.combo == 0, "Older version 2 saves load neutral combat defaults")
	# Invalid optional fields must be rejected instead of entering live combat.
	var valid = s.snapshot()
	for invalid in [{"charge_timer": -0.1}, {"fury_time": 99}, {"combo": 1.5}, {"charging": "true"}, {"ember_pos": [0.5]}, {"ember_pos": [1.2, 0.5]}]:
		var data = valid.duplicate(true)
		data.merge(invalid, true)
		file = FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(s._read_save(SAVE) == null, "Invalid combat state rejected: " + str(invalid))

## Clears whatever decision the journey left pending: relic, map, chest or event.
func settle(s) -> void:
	for i in range(4):
		if not s.offers.is_empty():
			s.choose_relic(s.offers[0])
		elif s.journey_phase == "map":
			s.choose_lane(0)
		elif s.journey_phase == "chest":
			s.open_chest()
		elif s.journey_phase == "event":
			s.resolve_encounter(false)

func _initialize() -> void:
	var s = fresh()
	check(s.hp == s.max_hp() and s.max_hp() == 120, "A new expedition starts at full health")
	check(s.spawn_delay > 0 and not s.click(), "The first enemy is still arriving")
	s.tick(s.SPAWN_DELAY + 0.01)
	check(s.click(), "Click attacks once the enemy has arrived")
	var hp = s.enemy_hp
	check(not s.click() and s.enemy_hp == hp, "Rate limit prevents event spam")
	s.paused = true
	s.tick(10)
	check(s.hp == s.max_hp() and not s.burst(), "Pause freezes damage and abilities")
	s.paused = false
	s.gold = 100
	var companion_price = s.price(1)
	check(s.buy(1) == 1 and s.wisps == 2 and s.gold == 100 - companion_price, "Companion purchase uses its price")
	s.tick(1.0)
	check(s.enemy_hp < hp, "Companions attack automatically")
	check(s.buy(-1) == 0 and s.buy(4) == 0, "Invalid upgrades cannot be bought")
	s.gold = 0
	check(s.buy(0) == 0, "Unaffordable purchase rejected")
	s.gold = 10000
	var afford = s.affordable(0)
	var cost = s.bulk_price(0, afford)
	check(afford > 5 and s.buy(0, afford) == afford and is_equal_approx(s.gold, 10000 - cost), "Bulk purchase buys as many as gold allows")
	s.gold = 0
	for i in range(5):
		s.damage_enemy(1e9)
	check(s.room == 6 and s.offers.size() == 3, "Fifth room gives three relic choices")
	check(s.offers[0] != s.offers[1] and s.offers[1] != s.offers[2] and s.offers[0] != s.offers[2], "Relic choices are distinct")
	hp = s.enemy_hp
	s.tick(10)
	check(not s.click() and s.enemy_hp == hp, "Relic choice blocks battle")
	check(not s.choose_relic(999), "Unknown relic rejected")
	check(s.choose_relic(s.offers[0]) and s.relics.size() == 1, "Chosen relic equipped")
	check(s.choose_lane(0), "A milestone also opens the map")
	while s.room < 10:
		settle(s)
		s.damage_enemy(1e9)
		settle(s)
	check(s.is_boss() and s.enemy_kind() == "boss", "Every tenth room is a boss")
	s.tick(s.BOSS_INTRO_FULL)
	# Boss: every third blow is a charged ember that Destello interrupts.
	s.hp = s.max_hp()
	s.boss_attacks = 2
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.05)
	check(s.charging, "The king charges a heavy attack on his third blow")
	s.burst_cooldown = 0
	s.spawn_delay = 0
	check(s.burst() and not s.charging and s.stun_time > 0, "Destello interrupts the charge and stuns")
	s.stun_time = 0
	s.boss_attacks = 2
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.05)
	var before = s.hp
	s.tick(s.CHARGE_TIME + 0.1)
	check(s.hp <= before - s.heavy_damage() + 1, "An uninterrupted charge lands a heavy blow")
	var bank = s.run_essence
	s.hp = s.max_hp()
	s.damage_enemy(1e9)
	check(s.run_essence >= bank + 5 and s.biome() == 1 and s.run_bosses == 1, "Boss rewards and biome transition")
	settle(s)
	# Echo of the crypts: enemies recover health while the bearer rests the blade.
	s.spawn_delay = 0
	s.enemy_hp = s.enemy_max * 0.5
	s.manual_rest = 2.0
	var hurt = s.enemy_hp
	s.attack_timer = -100
	s.tick(0.5)
	check(s.enemy_hp > hurt, "Crypt enemies regenerate when left alone")
	s.damage_enemy(1, false, true)
	check(s.echo_healing(), "Companion hits do not silence the crypt echo")
	s.click_cooldown = 0
	check(s.click() and not s.echo_healing(), "A manual attack stops the crypt echo")
	# Elite enemies.
	var base_max = s.enemy_max
	var base_reward = s.kill_reward()
	s.enemy_elite = true
	s.spawn_enemy(false)
	check(s.enemy_max > base_max * 2 and s.kill_reward() > base_reward * 2 and s.enemy_name().begins_with("Élite"), "Elites are tougher and richer")
	# Wandering ember.
	check(s.collect_ember() == "", "No ember, nothing to collect")
	s.ember_active = true
	s.spawn_delay = 0
	var kind = s.collect_ember()
	check(kind in s.EMBER_KINDS and not s.ember_active and s.total_embers == 1, "Embers grant a reward once")
	bank = s.run_essence
	var stock = s.essence
	s.hp = 1
	s.charging = false
	s.stun_time = 0
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.05)
	check(s.dead and s.essence == stock + bank, "Death banks all ascuas")
	s.finish_run()
	check(s.essence == stock + bank and s.runs == 1, "Cannot bank a finished run twice")
	s.essence = 200
	check(s.buy_legacy(0) and s.legacy[0] == 1, "Permanent upgrade purchase")
	check(s.buy_legacy(4) and s.legacy[4] == 1, "New permanent upgrades are available")
	check(not s.buy_legacy(State.LEGACY.size()), "Unknown permanent upgrade rejected")
	var permanent = s.essence
	s.restart()
	check(is_equal_approx(s.click_damage(), 7 * 1.08) and s.essence == permanent and s.gold == 30, "Rebirth preserves permanent power and currency")
	check(s.room == 1 and s.relics.is_empty() and s.wisps == 1 and s.focus == 0 and s.run_essence == 0, "Rebirth clears upgrades and restores the starting companion")
	check(s.hp == s.max_hp() and s.active(), "Rebirth restores full health")
	s.spawn_delay = 0
	check(s.burst() and not s.burst(), "Burst has a cooldown")
	# Persistence.
	s.gold = 153
	s.wisps = 2
	s.offers = [0, 3, 5]
	s.attack_timer = 2
	s.music_volume = 0.35
	check(s.save_game(SAVE), "Save created")
	var restored = State.new()
	check(restored.load_game(SAVE, false), "Save restored")
	check(restored.gold == 153 and restored.wisps == 2 and restored.legacy[0] == 1 and restored.legacy[4] == 1, "Run and permanent state restored")
	check(restored.offers == [0, 3, 5] and restored.attack_timer == 2, "Pending relic choice and enemy timer restored")
	check(is_equal_approx(restored.music_volume, 0.35), "Preferences restored")
	s.gold = 170
	check(s.save_game(SAVE), "Second save atomically replaces first")
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("corrupted")
	file.close()
	check(restored.load_game(SAVE, false) and restored.gold == 153, "Backup recovers a corrupted save")
	var old = s.snapshot()
	old.saved_at = Time.get_unix_time_from_system() - 86400
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(restored.load_game(SAVE) and restored.offline_reward == 960, "Offline income capped at four hours")
	restored.save_game(SAVE)
	var reclaimed = State.new()
	check(reclaimed.load_game(SAVE) and reclaimed.offline_reward == 0, "Persisted offline reward cannot be claimed again")
	# Version 1 saves from 0.1.0 are migrated.
	var legacy_save = {"version": 1, "room": 7, "gold": 50, "hp": 80, "enemy_hp": 10, "blade": 2, "wisps": 1, "armor": 0,
		"relics": ["fang"], "offers": [], "essence": 12, "run_essence": 3, "legacy": [1, 2, 0], "best": 9,
		"total_kills": 40, "runs": 2, "dead": false, "muted": true, "reduced_motion": false, "burst_cooldown": 0,
		"attack_timer": 1, "saved_at": Time.get_unix_time_from_system()}
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_save))
	file.close()
	DirAccess.remove_absolute(SAVE + ".bak")
	var migrated = State.new()
	check(migrated.load_game(SAVE, false), "Version 1 save loads")
	check(migrated.room == 7 and migrated.legacy.size() == State.LEGACY.size() and migrated.legacy[1] == 2 and migrated.master_volume == 0.0, "Version 1 save migrated")
	check(migrated.run_start_best == 9 and not migrated.is_record(), "Migrated expeditions start from the stored best")
	test_legacy_cap()
	test_combat_persistence()
	test_records()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	print("PROGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
