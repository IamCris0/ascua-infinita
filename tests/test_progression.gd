extends SceneTree
const State = preload("res://scripts/run_state.gd")
var checks: int = 0
var failures: int = 0
const SAVE = "user://qa_progression.json"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var s = State.new()
	check(s.click(), "First click must attack")
	var hp = s.enemy_hp
	check(not s.click() and s.enemy_hp == hp, "Rate limit prevents event spam")
	s.paused = true
	s.tick(5)
	check(s.hp == 100 and not s.burst(), "Pause freezes damage and abilities")
	s.paused = false
	s.gold = 100
	check(s.buy(1) and s.wisps == 1 and s.gold == 80, "Companion purchase uses correct price")
	s.tick(1)
	check(s.enemy_hp < hp, "Companion attacks automatically")
	check(not s.buy(-1) and not s.buy(3), "Invalid upgrades cannot be bought")
	s.gold = 0
	check(not s.buy(0), "Unaffordable purchase rejected")
	for i in range(5):
		s.damage_enemy(100000)
	check(s.room == 6 and s.offers.size() == 3, "Fifth room gives three relic choices")
	check(s.offers[0] != s.offers[1] and s.offers[1] != s.offers[2], "Relic choices are distinct")
	hp = s.enemy_hp
	s.tick(10)
	check(not s.click() and s.enemy_hp == hp, "Relic choice blocks battle")
	check(not s.choose_relic(999), "Unknown relic rejected")
	check(s.choose_relic(s.offers[0]) and s.relics.size() == 1, "Chosen relic equipped")
	while s.room < 10:
		s.damage_enemy(100000)
	check(s.is_boss() and s.enemy_kind() == "boss", "Every tenth room is a boss")
	var bank = s.run_essence
	s.damage_enemy(100000)
	check(s.run_essence == bank + 5 and s.biome() == 1, "Boss rewards and biome transition")
	s.choose_relic(s.offers[0])
	bank = s.run_essence
	s.hp = 1
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.02)
	check(s.dead and s.essence == bank and s.run_essence == 0, "Death banks all ascuas")
	s.finish_run()
	check(s.essence == bank and s.runs == 1, "Cannot bank a finished run twice")
	check(s.buy_legacy(0) and s.legacy[0] == 1, "Permanent upgrade purchase")
	var permanent = s.essence
	s.restart()
	check(s.click_damage() == 7 and s.essence == permanent, "Rebirth preserves permanent power and currency")
	check(s.room == 1 and s.gold == 0 and s.relics.is_empty() and s.wisps == 0, "Rebirth clears temporary upgrades")
	check(s.hp == s.max_hp() and s.active(), "Rebirth restores full health")
	check(s.burst() and not s.burst(), "Burst has a cooldown")
	s.gold = 153
	s.wisps = 2
	s.offers = [0, 3, 5]
	s.attack_timer = 2
	check(s.save_game(SAVE), "Save created")
	var restored = State.new()
	check(restored.load_game(SAVE, false), "Save restored")
	check(restored.gold == 153 and restored.wisps == 2 and restored.legacy[0] == 1, "Run and permanent state restored")
	check(restored.offers == [0, 3, 5] and restored.attack_timer == 2, "Pending relic choice and enemy timer restored")
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
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("PROGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
