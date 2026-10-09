extends SceneTree
## Portadores: unlocks, the choice at the bonfire, stats and techniques.
## godot --headless --path . --script tests/test_bearers.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_bearers.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

## A fresh state already playing as `id` (unlocked for the test).
func playing(id: String):
	var s = State.new()
	s.rng.seed = 41
	s.achievements = ["parry", "bell", "chests"]
	s.dead = true
	s.set_bearer(id)
	s.restart()
	s.spawn_delay = 0
	s.ember_cooldown = 99999
	return s

func _initialize() -> void:
	var s = State.new()
	s.restart()
	check(s.bearer == "bearer" and s.bearer_unlocked_by("bearer"), "Everyone starts as the Portador")
	check(not s.bearer_unlocked_by("sentinel") and not s.bearer_unlocked_by("summoner") and not s.bearer_unlocked_by("wanderer"), "The other bearers start locked")
	var heard = []
	s.bearer_unlocked.connect(func(id): heard.append(id))
	s.unlock("parry")
	check(heard == ["sentinel"] and s.bearer_unlocked_by("sentinel"), "Guardia perfecta unlocks the Centinela and announces it")
	check(not s.set_bearer("sentinel"), "The bearer cannot change during an expedition")
	s.finish_run()
	check(not s.set_bearer("summoner") and not s.set_bearer("dragon"), "Locked or unknown bearers cannot be chosen")
	check(s.set_bearer("sentinel") and s.bearer == "sentinel", "An unlocked bearer is chosen at the bonfire")
	s.restart()
	check(s.history[0].bearer == "bearer", "The log records who led each expedition")

	# Stats against the Portador.
	var base = playing("bearer")
	var sentinel = playing("sentinel")
	var summoner = playing("summoner")
	var wanderer = playing("wanderer")
	check(is_equal_approx(sentinel.max_hp(), base.max_hp() * 1.1) and is_equal_approx(sentinel.click_damage(), base.click_damage() * 0.85), "Centinela: more health, weaker clicks")
	check(is_equal_approx(sentinel.perfect_window(), base.perfect_window() + 0.1), "Centinela: a longer perfect parry")
	check(summoner.wisps == base.wisps + 1 and is_equal_approx(summoner.wisp_damage(), base.wisp_damage() * 1.3) and is_equal_approx(summoner.click_damage(), base.click_damage() * 0.8), "Invocadora: one more companion, stronger companions, weaker clicks")
	check(is_equal_approx(wanderer.gold_multiplier(), base.gold_multiplier() * 1.1) and is_equal_approx(wanderer.max_hp(), base.max_hp() * 0.9), "Errante: more gold, less health")
	var plain = State.new()
	plain.restart()
	check(is_equal_approx(base.burst_max_cooldown(), plain.burst_max_cooldown()) and is_equal_approx(sentinel.burst_max_cooldown(), base.burst_max_cooldown() / 0.85), "Portador: Destello recharges 15% faster than the others")
	check(is_equal_approx(base.burst_damage(), wanderer.burst_damage() * 1.15), "Portador: Destello hits 15% harder")

	# Techniques.
	var walls = []
	sentinel.walled.connect(func(): walls.append(1))
	sentinel.enemy_hp = 1e12
	sentinel.enemy_max = 1e12
	sentinel.burst()
	check(is_equal_approx(sentinel.wall, sentinel.max_hp() * sentinel.WALL_SHARE) and sentinel.wall_time == sentinel.WALL_TIME, "Muro de brasas rises with Destello")
	var hp = sentinel.hp
	var wall = sentinel.wall
	var blow = sentinel.enemy_damage()
	sentinel.stun_time = 0
	sentinel.attack_timer = sentinel.attack_interval() - 0.01
	sentinel.tick(0.02)
	check(sentinel.hp == hp and is_equal_approx(sentinel.wall, wall - blow) and walls.size() == 1, "The wall absorbs a blow")
	sentinel.wall = blow * 0.25
	sentinel.attack_timer = sentinel.attack_interval() - 0.01
	sentinel.tick(0.02)
	check(is_equal_approx(hp - sentinel.hp, blow * 0.75) and sentinel.wall == 0, "A blow larger than the wall breaks through")
	sentinel.burst_cooldown = 0
	sentinel.burst()
	sentinel.stun_time = 100
	sentinel.tick(sentinel.WALL_TIME + 0.1)
	check(sentinel.wall == 0, "The wall fades after six seconds")
	var auto = summoner.auto_damage()
	summoner.burst()
	check(summoner.summoned() == 3 and is_equal_approx(summoner.auto_damage(), auto * (summoner.wisps + 3) / float(summoner.wisps)), "Llamada del enjambre adds three companions")
	summoner.hp = 1e9
	summoner.enemy_hp = 1e12
	summoner.enemy_max = 1e12
	summoner.tick(summoner.SUMMON_TIME + 0.1)
	check(summoner.summoned() == 0, "The swarm leaves after eight seconds")
	var gold = wanderer.gold
	var told = []
	wanderer.fortune.connect(func(amount): told.append(amount))
	wanderer.enemy_hp = 1e12
	wanderer.enemy_max = 1e12
	wanderer.burst()
	check(is_equal_approx(wanderer.gold - gold, floor(wanderer.room_reward() * wanderer.FORTUNE)) and told.size() == 1, "Golpe de fortuna leaves gold")
	gold = base.gold
	base.enemy_hp = 1e12
	base.enemy_max = 1e12
	base.burst()
	check(base.gold == gold and base.wall == 0 and base.summoned() == 0, "The Portador's Destello has no extra effect")
	for id in ["sentinel", "summoner", "wanderer"]:
		var t = playing(id)
		t.room = 10
		t.spawn_enemy(false)
		t.spawn_delay = 0
		t.charging = true
		t.charge_timer = 2.0
		var interrupted = []
		t.burst_released.connect(func(was): interrupted.append(was))
		t.burst()
		check(interrupted == [true] and not t.charging, "Destello still interrupts a boss as " + id)

	# Persistence.
	s = playing("summoner")
	s.burst()
	s.wall = 12.0
	s.wall_time = 3.0
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Save as the Invocadora")
	check(restored.bearer == "summoner" and is_equal_approx(restored.summon_time, s.summon_time) and restored.wall == 12.0 and restored.wall_time == 3.0, "The bearer and its active technique survive a reload")
	var data: Dictionary = s.snapshot()
	data.achievements = []
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and restored.bearer == "bearer", "A bearer without its achievement falls back to the Portador")
	data = s.snapshot()
	data.bearer = "dragon"
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(restored._read_save(SAVE) == null, "An unknown bearer is rejected")
	data = s.snapshot()
	data.erase("bearer")
	data.erase("wall")
	data.erase("wall_time")
	data.erase("summon_time")
	for run in data.history:
		run.erase("bearer")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(restored.load_game(SAVE, false) and restored.bearer == "bearer" and restored.wall == 0, "Saves from before the bearers load as the Portador")
	s.finish_run()
	check(s.wall == 0 and s.summon_time == 0, "Techniques end with the expedition")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("BEARERS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
