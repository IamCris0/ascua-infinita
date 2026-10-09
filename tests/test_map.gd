extends SceneTree
## Mapa de caminos, cofres and the Rueda del eclipse.
## godot --headless --path . --script tests/test_map.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_map.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

## A cleared milestone with its relic taken: the map waits for a lane.
func at_map(seed_value: int = 5):
	var s = State.new()
	s.rng.seed = seed_value
	s.restart()
	s.ember_cooldown = 99999
	s.room = 5
	s.spawn_enemy(false)
	s.damage_enemy(1e9)
	s.choose_relic(s.offers[0])
	return s

## Enters a lane whose first chamber holds `kind`.
func at_node(kind: String, seed_value: int = 5):
	var s = at_map(seed_value)
	s.lanes[1] = [kind, "fight", "fight", "fight"]
	s.choose_lane(1)
	return s

func _initialize() -> void:
	# Lanes keep their character on every map.
	var musts_kept = true
	var known = true
	var sizes = true
	for seed_value in range(30):
		var s = at_map(seed_value)
		sizes = sizes and s.lanes.size() == 3 and s.lanes.all(func(nodes): return nodes.size() == s.LANE_LENGTH)
		for i in range(s.LANES.size()):
			for must in s.LANES[i].must:
				musts_kept = musts_kept and s.lanes[i].has(must)
			for node in s.lanes[i]:
				known = known and s.NODES.has(node) and (s.LANES[i].weights.has(node))
	check(sizes, "Every map has three lanes of four chambers")
	check(musts_kept, "Each lane holds what defines it: a rest, an elite and a chest, the Rueda")
	check(known, "Lanes only hold nodes from their own table")
	var capped = true
	for seed_value in range(30):
		var m = at_map(seed_value + 100)
		for nodes in m.lanes:
			for node in m.NODE_MAX:
				capped = capped and nodes.count(node) <= m.NODE_MAX[node]
	check(capped, "No lane repeats a node beyond its limit (one Rueda, two elites...)")

	var s = at_map()
	check(s.node_at(s.room) == "" and s.lane == -1, "No chamber has a node before a lane is chosen")
	s.lanes[0] = ["fight", "rest", "chest", "elite"]
	check(s.choose_lane(0) and s.node_at(6) == "fight" and s.node_at(9) == "elite" and s.node_at(10) == "", "The chosen lane covers four chambers, not the milestone")
	s.spawn_delay = 0
	s.hp = 10
	s.damage_enemy(1e12)
	check(s.room == 7 and s.hp >= 10 + s.max_hp() * s.rest_heal() - 0.01 and not s.enemy_elite and s.active(), "A rest heals on arrival and its rival is never an elite")
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	check(s.room == 8 and s.journey_phase == "chest" and not s.active(), "A chest waits before the fight")
	s.tick(30)
	check(s.journey_phase == "chest" and s.enemy_hp == s.enemy_max, "Combat is frozen while the chest is closed")
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.journey_phase == "chest" and restored.chest_tier == s.chest_tier and restored.node_at(9) == "elite", "A pending chest and the lane survive a reload")
	var gold = s.gold
	var essence = s.run_essence
	var wisps = s.wisps
	var loot = s.open_chest()
	check(loot.size() == s.chest_tier + 1 and s.total_chests == 1 and s.journey_phase.is_empty(), "A chest gives one reward per tier and opens once")
	check(s.open_chest().is_empty(), "An opened chest cannot be opened again")
	var gained_gold = 0.0
	var gained_essence = 0
	for entry in loot:
		check(not s.loot_text(entry).is_empty(), "Every reward has a description: " + entry.kind)
		if entry.kind == "gold":
			gained_gold += entry.amount
		elif entry.kind == "essence":
			gained_essence += int(entry.amount)
	check(is_equal_approx(s.gold - gold, gained_gold) and s.run_essence - essence == gained_essence, "Chest gold and ascuas are paid exactly")
	check(s.wisps >= wisps, "Companions from a chest are kept")
	s.offers.clear()
	s.spawn_delay = 0
	s.damage_enemy(1e12)
	check(s.room == 9 and s.enemy_elite, "An elite chamber after the chest")

	# Loot tables.
	var relics_in_eclipse = true
	var at_most_one_relic = true
	var distinct = true
	var no_heal_at_full = true
	for seed_value in range(60):
		var t = at_map(seed_value)
		for tier in range(3):
			var rolled = t.roll_loot(tier)
			var relics = rolled.filter(func(entry): return entry.kind == "relic").size()
			var kinds = {}
			for entry in rolled:
				kinds[entry.kind] = true
			distinct = distinct and kinds.size() == rolled.size()
			at_most_one_relic = at_most_one_relic and relics <= 1
			if tier == 2:
				relics_in_eclipse = relics_in_eclipse and relics == 1
			if tier == 0:
				at_most_one_relic = at_most_one_relic and relics == 0
			no_heal_at_full = no_heal_at_full and not rolled.any(func(entry): return entry.kind == "heal")
	check(relics_in_eclipse, "An eclipse chest always holds a relic")
	check(at_most_one_relic, "A chest never holds two relics, and a wooden one none")
	check(no_heal_at_full, "No healing is offered at full health")
	check(distinct, "The rewards of one chest are all different")
	s = at_node("chest")
	s.chest_tier = 2
	s.open_chest()
	check(s.offers.size() == 3 and not s.active(), "A relic from a chest is chosen like any other")
	check(s.choose_relic(s.offers[0]) and s.active(), "Combat resumes after the chest's relic")

	# The Rueda del eclipse.
	s = at_node("wheel")
	check(s.journey_phase == "event" and s.encounter_kind == "wheel" and not s.active(), "The Rueda waits before the fight")
	s.gold = 0
	check(not s.can_accept_encounter() and not s.resolve_encounter(true), "No bet without the gold")
	check(s.encounter_cost() == int(s.room_reward() * 2.5), "The bet follows the chamber's reward")
	var seen = {}
	var paid_right = true
	for i in range(120):
		s.offers.clear()
		s.journey_phase = "event"
		s.encounter_kind = "wheel"
		s.gold = 100000
		s.hp = s.max_hp() * 0.4
		var bet = s.encounter_cost()
		var hp = s.hp
		essence = s.run_essence
		check(s.resolve_encounter(true), "Spin %d" % i) if i == 0 else s.resolve_encounter(true)
		var sector: String = s.WHEEL[s.wheel_result]
		seen[sector] = true
		match sector:
			"gold2": paid_right = paid_right and is_equal_approx(s.gold, 100000 + bet)
			"gold3": paid_right = paid_right and is_equal_approx(s.gold, 100000 + 2 * bet) and s.achievements.has("jackpot")
			"nothing": paid_right = paid_right and is_equal_approx(s.gold, 100000 - bet) and s.journey_phase.is_empty()
			"heal": paid_right = paid_right and s.hp > hp
			"essence": paid_right = paid_right and s.run_essence == essence + 3
			"relic": paid_right = paid_right and s.offers.size() == 3
			"chest": paid_right = paid_right and s.journey_phase == "chest" and s.chest_tier == 1
	check(seen.size() == 7, "Every kind of sector comes up: %s" % [seen.keys()])
	check(paid_right, "Each sector pays what it shows")
	check(s.total_spins == 120, "Spins are counted")
	check(s.WHEEL.count("nothing") == 3 and s.WHEEL.size() == 10, "Three sectors of ten are empty, as the screen shows")
	s = at_node("wheel")
	gold = s.gold
	check(s.resolve_encounter(false) and s.gold == gold and s.active() and s.total_spins == 0, "Walking past the Rueda costs nothing")

	# Persistence and older saves.
	s = at_map(9)
	var data: Dictionary = s.snapshot()
	data.journey_phase = "route"
	data.encounter_kind = "merchant"
	data.erase("lanes")
	data.erase("lane")
	data.erase("lane_start")
	data.erase("chest_tier")
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and restored.journey_phase == "map" and restored.lanes.size() == 3 and restored.lane_start == restored.room and restored.encounter_kind.is_empty(), "A pending route from an older save becomes a map")
	for bad in [{"lanes": [["fight", "fight"]]}, {"lanes": [["dragon", "fight", "fight", "fight"]]}, {"lane": 4}, {"chest_tier": 3}, {"journey_phase": "chest", "offers": [1, 2, 3]}, {"journey_phase": "event", "encounter_kind": ""}, {"journey_phase": "map", "lane": 0}]:
		data = at_map(9).snapshot()
		for key in bad:
			data[key] = bad[key]
		f = FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		check(restored._read_save(SAVE) == null, "Invalid map state rejected: %s" % [bad])
	s = at_node("fight")
	s.total_chests = 14
	s.journey_phase = "chest"
	s.chest_tier = 0
	s.open_chest()
	check(s.achievements.has("chests"), "Fifteen chests earn Cazatesoros")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("MAP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
