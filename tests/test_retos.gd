extends SceneTree
## Retos (daily and weekly), achievement and collection rewards, the
## bestiary and the statistics.
## godot --headless --path . --script tests/test_retos.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_retos.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 51
	s.restart()
	s.spawn_delay = 0
	s.ember_cooldown = 99999
	return s

## Retos of a given day with one chosen kind put first.
func with_mission(s, kind: String, is_weekly: bool = false) -> Dictionary:
	var list: Array = s.weekly if is_weekly else s.daily
	list[0] = {"kind": kind, "target": s.MISSION_KINDS[kind]["weekly" if is_weekly else "daily"], "progress": 0, "claimed": false}
	return list[0]

func _initialize() -> void:
	check(State.ACHIEVEMENTS.size() == 30, "Thirty achievements")
	var ids = {}
	var groups_ok = true
	for entry in State.ACHIEVEMENTS:
		ids[entry.id] = true
		groups_ok = groups_ok and entry.group in State.ACHIEVEMENT_GROUPS and (entry.reward.get("essence", 0) + entry.reward.get("scrap", 0)) > 0
	check(ids.size() == 30 and groups_ok, "Achievement ids are unique and each has a group and a reward")

	# Dates.
	var monday = State.day_number({"year": 2026, "month": 10, "day": 5})
	var sunday = State.day_number({"year": 2026, "month": 10, "day": 11})
	var next_monday = State.day_number({"year": 2026, "month": 10, "day": 12})
	check(State.week_number(monday) == State.week_number(sunday) and State.week_number(next_monday) == State.week_number(monday) + 1, "Weeks run from Monday to Sunday")

	# The same day gives the same retos to everyone.
	var a = fresh()
	var b = fresh()
	a.refresh_missions(monday)
	b.rng.seed = 999
	b.refresh_missions(monday)
	check(a.daily == b.daily and a.weekly == b.weekly and a.daily.size() == 3 and a.weekly.size() == 2, "Retos depend only on the date")
	var kinds = a.daily.map(func(m): return m.kind)
	check(kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2], "The three daily retos are different")
	check(not a.refresh_missions(monday), "Nothing changes on the same day")
	a.daily[0].progress = 1
	a.weekly[0].progress = 1
	var weekly_before = a.weekly.duplicate(true)
	check(a.refresh_missions(monday + 1) and a.mission_day == monday + 1 and a.daily.all(func(m): return m.progress == 0), "A new day brings fresh daily retos")
	check(a.weekly == weekly_before, "The weekly retos last the whole week")
	var differs = false
	for day in range(monday + 1, monday + 8):
		var c = fresh()
		c.refresh_missions(day)
		differs = differs or c.daily.map(func(m): return m.kind) != b.daily.map(func(m): return m.kind)
	check(differs, "Different days pick different retos")
	check(a.refresh_missions(next_monday) and a.mission_week == State.week_number(next_monday) and a.weekly.all(func(m): return m.progress == 0), "A new week brings fresh weekly retos")

	# Progress from play.
	var s = fresh()
	s.refresh_missions(monday)
	var kills = with_mission(s, "kills")
	var room = with_mission(s, "room", true)
	var heard = []
	s.mission_completed.connect(func(text): heard.append(text))
	kills.target = 3
	for i in range(3):
		s.spawn_delay = 0
		s.damage_enemy(1e12)
	check(kills.progress == 3 and s.mission_done(kills) and heard.size() == 1, "Victories advance a reto and its completion is announced")
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	check(kills.progress == 3, "Progress stops at the target")
	check(room.progress == s.room, "The chamber reto keeps the deepest chamber")
	var essence = s.essence
	var scrap = s.scrap
	check(s.claim_mission(false, 0) and s.essence == essence + 12 and s.scrap == scrap + 4 and s.daily_done == 1 and s.total_missions == 1, "Claiming a daily reto pays its reward")
	check(not s.claim_mission(false, 0), "A reto is claimed once")
	check(not s.claim_mission(true, 0), "An unfinished reto cannot be claimed")
	room.progress = room.target
	essence = s.essence
	check(s.claim_mission(true, 0) and s.essence == essence + 50 and s.achievements.has("weekly"), "A weekly reto pays more and earns Semana de brasas")
	for kind in ["parries", "weak", "chests", "interrupts", "embers", "elites", "bosses"]:
		var t = fresh()
		t.refresh_missions(monday)
		var m = with_mission(t, kind)
		match kind:
			"parries":
				t.attack_timer = t.attack_interval() - 0.1
				t.parry()
				t.tick(0.15)
			"weak":
				t.weak_active = true
				t.weak_timer = 2.0
				t.strike_weak()
			"chests":
				t.journey_phase = "chest"
				t.open_chest()
			"interrupts":
				t.room = 10
				t.spawn_enemy(false)
				t.spawn_delay = 0
				t.charging = true
				t.charge_timer = 2.0
				t.burst()
			"embers":
				t.ember_active = true
				t.collect_ember()
			"elites":
				t.enemy_elite = true
				t.damage_enemy(1e12)
			"bosses":
				t.room = 10
				t.spawn_enemy(false)
				t.spawn_delay = 0
				t.damage_enemy(1e12)
		check(m.progress == 1, "Play advances the reto: " + kind)
	s = fresh()
	s.daily_done = 9
	s.refresh_missions(monday)
	s.daily[1].progress = s.daily[1].target
	s.claim_mission(false, 1)
	check(s.achievements.has("daily"), "Ten daily retos earn Constancia")

	# Achievement and category rewards.
	s = fresh()
	s.unlock("king")
	essence = s.essence
	check(s.claimable_count() >= 1 and s.claim_achievement("king") and s.essence == essence + 15, "An achievement's reward is claimed once earned")
	check(not s.claim_achievement("king") and not s.claim_achievement("bell"), "Rewards are claimed once and only when earned")
	check(not s.claim_category("Reliquias"), "An incomplete category has no reward yet")
	for relic in s.RELIC_IDS:
		s.remember("relic:" + relic)
	essence = s.essence
	scrap = s.scrap
	check(s.category_complete("Reliquias") and s.claim_category("Reliquias") and s.essence == essence + 25 and s.scrap == scrap + 8, "A complete category pays its reward")
	check(not s.claim_category("Reliquias"), "A category is claimed once")

	# New achievements.
	s = fresh()
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	check(s.achievements.has("untouched"), "A boss beaten without being hit earns Intocable")
	s = fresh()
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.hp = 1e6
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.02)
	s.damage_enemy(1e12)
	check(not s.achievements.has("untouched"), "A blow taken spoils Intocable")
	s = fresh()
	s._gain_gold(100000)
	check(s.achievements.has("rich"), "100.000 gold in one expedition earns Bolsa llena")
	s = fresh()
	s.total_kills = 499
	s.damage_enemy(1e12)
	check(s.achievements.has("kills_500"), "500 victories earn Exterminador")
	s = fresh()
	s.room = 49
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	check(s.achievements.has("room_50"), "Reaching chamber 50 earns Más allá")
	s = fresh()
	s.scrap = 10000
	for i in range(3):
		s.buy_mastery(2)
	check(s.achievements.has("masteries"), "A mastery at its maximum earns Maestro")
	s = fresh()
	for id in ["parry", "bell", "chests"]:
		s.unlock(id)
	check(s.achievements.has("bearers"), "Unlocking every bearer earns Muchas manos")
	s = fresh()
	s.total_spins = 9
	s.gold = 1e9
	s.journey_phase = "event"
	s.encounter_kind = "wheel"
	s.resolve_encounter(true)
	check(s.achievements.has("wheel_10"), "Ten spins earn Jugador empedernido")
	s = fresh()
	s.total_kills = 2000
	s.best = 60
	s.unlock_earned()
	check(s.achievements.has("kills_2000") and s.achievements.has("room_60"), "Older saves receive what their counters prove")

	# Bestiary and time.
	s = fresh()
	s.damage_enemy(1e12)
	check(s.bestiary.get("slime", 0) == 1, "The bestiary counts victories per enemy")
	s.spawn_delay = 0
	var time = s.total_time
	s.hp = 1e6
	s.tick(1.0)
	check(is_equal_approx(s.total_time, time + 1.0), "Combat time is counted")

	# Persistence.
	s = fresh()
	s.refresh_missions(monday)
	s.daily[0].progress = 1
	s.unlock("king")
	s.claim_achievement("king")
	s.bestiary = {"slime": 4, "king": 1}
	s.collection_claimed = ["Reliquias"]
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Save with retos")
	check(restored.daily == s.daily and restored.weekly == s.weekly and restored.mission_day == monday and restored.achievements_claimed == ["king"] and restored.bestiary == s.bestiary and restored.collection_claimed == ["Reliquias"], "Retos, claims and the bestiary survive a reload")
	var good: Dictionary = s.snapshot()
	var bad_cases = [
		{"achievements_claimed": ["bell"]},
		{"collection_claimed": ["Dragones"]},
		{"bestiary": {"slime": -1}},
		{"missions": {"day": 1, "week": 1, "daily": [{"kind": "fly", "target": 3, "progress": 0, "claimed": false}], "weekly": []}},
		{"missions": {"day": 1, "week": 1, "daily": [{"kind": "kills", "target": 3, "progress": 5, "claimed": false}], "weekly": []}},
		{"missions": {"day": 1, "week": 1, "daily": [], "weekly": [{}, {}, {}]}}]
	for bad in bad_cases:
		var data = good.duplicate(true)
		for key in bad:
			data[key] = bad[key]
		var f = FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		check(restored._read_save(SAVE) == null, "Invalid retos rejected: %s" % [bad])
	var old = good.duplicate(true)
	for key in ["achievements_claimed", "collection_claimed", "bestiary", "missions", "total_missions", "daily_done", "total_time", "fight_hits"]:
		old.erase(key)
	var f2 = FileAccess.open(SAVE, FileAccess.WRITE)
	f2.store_string(JSON.stringify(old))
	f2.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and restored.achievements.has("king") and not restored.achievements_claimed.has("king") and restored.daily.is_empty(), "Older saves keep their achievements with the reward waiting")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("RETOS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
