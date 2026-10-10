extends SceneTree
## Variety of 0.11: new relics and synergies, élite affixes, duels and the
## Fragua errante.
## godot --headless --path . --script tests/test_variety.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_variety.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 61
	s.restart()
	s.spawn_delay = 0
	s.wisps = 0
	s.ember_cooldown = 99999
	return s

## An élite in chamber 7 with exactly these affixes.
func elite(affixes: Array):
	var s = fresh()
	s.room = 7
	s.enemy_elite = true
	s.spawn_enemy(false)
	s.spawn_delay = 0
	s.affixes = affixes
	s.weak_cooldown = 9.0
	return s

## A milestone whose first lane chamber holds `kind`, entered through the map.
func at_node(kind: String):
	var s = fresh()
	s.room = 5
	s.spawn_enemy(false)
	s.damage_enemy(1e12)
	s.choose_relic(s.offers[0])
	s.lanes[0] = [kind, "fight", "fight", "fight"]
	s.choose_lane(0)
	return s

func _initialize() -> void:
	check(State.RELICS.size() == 12 and State.RELIC_IDS.size() == 12 and State.SYNERGIES.size() == 7, "Twelve relics and seven synergies")
	var ids_match = true
	for i in range(State.RELICS.size()):
		ids_match = ids_match and State.RELICS[i].id == State.RELIC_IDS[i]
	check(ids_match, "Relic ids follow the relic list")
	check(State.new().collection_catalog().size() == 36, "The collection grows to 36 entries")

	# Relics.
	var s = elite([])
	var hp = s.enemy_hp
	s.damage_enemy(100)
	var plain_hit = hp - s.enemy_hp
	s.relics = ["horn"]
	hp = s.enemy_hp
	s.damage_enemy(100)
	check(is_equal_approx(hp - s.enemy_hp, plain_hit * 1.3), "Cuerno de guerra: +30% against élites")
	s = fresh()
	s.relics = ["horn"]
	hp = s.enemy_hp
	s.damage_enemy(10)
	check(is_equal_approx(hp - s.enemy_hp, 10), "Cuerno de guerra does nothing against ordinary rivals")
	s = fresh()
	var share = s.block_share()
	s.relics = ["frost"]
	check(is_equal_approx(s.block_share(), share - 0.15), "Escudo de escarcha: blocks stop more")
	s.attack_timer = s.attack_interval() - 0.1
	s.parry()
	s.tick(0.15)
	check(s.stun_time > s.PARRY_STUN, "Escudo de escarcha: a perfect parry stuns longer")
	s = fresh()
	s.relics = ["tear"]
	s.hp = 50
	s.enemy_hp = 1e9
	s.enemy_max = 1e9
	s.attack_timer = -100
	s.tick(2.0)
	check(is_equal_approx(s.hp, 50 + s.max_hp() * 0.005 * 2.0), "Lágrima de fénix heals 0,5% per second")
	s = fresh()
	var duration = s.weak_duration()
	s.relics = ["lens"]
	check(is_equal_approx(s.weak_duration(), duration + 1.0), "Lente de cazador lengthens weak points")
	var waits = []
	for i in range(30):
		waits.append(s._weak_wait())
	check(waits.max() <= 10.0 / 1.4 + 0.001, "Lente de cazador brings weak points sooner")
	s = fresh()
	var loot = s.roll_loot(0)
	s.relics = ["bag"]
	var more = s.roll_loot(0)
	check(loot.size() == 1 and more.size() == 2, "Bolsa sin fondo: one more reward per chest")

	# Synergies.
	s = elite([])
	s.relics = ["horn", "lens"]
	s.burst_cooldown = 10.0
	s.weak_active = true
	s.weak_timer = 2.0
	s.strike_weak()
	check(s.has_synergy("hunter") and is_equal_approx(s.burst_cooldown, 10.0 - s.WEAK_RECHARGE - 3.0), "Cazador implacable: weak points on élites speed Destello")
	s = fresh()
	s.relics = ["frost", "tear"]
	s.hp = 50
	s.attack_timer = s.attack_interval() - 0.1
	s.parry()
	s.tick(0.15)
	check(s.hp >= 50 + s.max_hp() * 0.05, "Hielo y llama: a perfect parry heals")
	var wooden = false
	for seed_value in range(40):
		var t = at_node("fight")
		t.rng.seed = seed_value
		t.relics = ["bag", "coin"]
		t.lanes[0][1] = "chest"
		t.spawn_delay = 0
		t.damage_enemy(1e12)
		wooden = wooden or t.chest_tier == 0
	check(not wooden, "Fortuna sin fondo: no wooden chests")

	# Affixes.
	s = fresh()
	s.room = 7
	s.enemy_elite = true
	s.spawn_enemy(false)
	check(s.affixes.size() == 1 and s.affixes[0] in s.AFFIX_IDS, "Every élite carries an affix")
	s.enemy_elite = false
	s.spawn_enemy(false)
	check(s.affixes.is_empty(), "Ordinary rivals carry none")
	s = elite(["swift"])
	var plain = elite([])
	check(is_equal_approx(s.attack_interval(), plain.attack_interval() * 0.65), "Veloz attacks sooner")
	check(s.enemy_name() == "Élite veloz · " + s.enemy_title() and s.affix_label() == "ÉLITE VELOZ", "The name tells the affix")
	s = elite(["armored"])
	hp = s.enemy_hp
	s.damage_enemy(100)
	check(is_equal_approx(hp - s.enemy_hp, 60), "Acorazada: −40% while above half health")
	s.enemy_hp = s.enemy_max * 0.4
	hp = s.enemy_hp
	s.damage_enemy(100)
	check(is_equal_approx(hp - s.enemy_hp, 100), "Acorazada: full damage below half health")
	s = elite(["burning"])
	s.hp = 1000
	s.attack_timer = s.attack_interval() - 0.01
	var blow = s.enemy_damage()
	s.tick(0.02)
	check(s.burn_time > 0 and is_equal_approx(s.burn_dps, blow * 0.2), "Ardiente: a blow sets the bearer burning")
	hp = s.hp
	s.tick(1.0)
	check(is_equal_approx(hp - s.hp, s.burn_dps * 1.0), "The burn hurts over time")
	s.tick(3.0)
	check(s.burn_time == 0, "The burn ends")
	s = elite(["burning"])
	s.hp = 1000
	s.attack_timer = s.attack_interval() - 0.1
	s.parry()
	s.tick(0.15)
	check(s.burn_time == 0, "A perfect parry avoids the burn")
	s = elite(["vampiric"])
	s.hp = 1000
	s.enemy_hp = s.enemy_max * 0.5
	s.attack_timer = s.attack_interval() - 0.01
	s.tick(0.02)
	check(is_equal_approx(s.enemy_hp, s.enemy_max * 0.6), "Vampírica heals when it hits")
	s = elite(["thorny"])
	s.hp = 1000
	var heard = []
	s.thorned.connect(func(amount): heard.append(amount))
	s.click_cooldown = 0
	s.click()
	s.tick(s.HIT_DELAY + 0.01)
	check(heard.size() == 1 and is_equal_approx(1000 - s.hp, s.enemy_damage() * 0.08), "Espinosa: each manual hit hurts back")
	s.damage_enemy(1e12)
	check(s.burn_time == 0 and s.affixes.size() <= 1, "A new rival starts clean")
	s = elite(["burning"])
	s.hp = 1
	s.burn_time = 3.0
	s.burn_dps = 100
	s.tick(0.1)
	check(s.dead, "A burn can end the expedition")

	# Duel and the Fragua errante.
	s = at_node("duel")
	check(s.enemy_elite and s.affixes.size() == 2 and s.affixes[0] != s.affixes[1], "A duel rival is an élite with two affixes")
	var pieces = s.armory.size()
	s.damage_enemy(1e12)
	check(s.armory.size() == pieces + 1, "Winning a duel leaves a piece of the Arsenal")
	s = at_node("smithy")
	check(s.journey_phase == "event" and s.encounter_kind == "smithy" and s.smithy_kind >= 0 and s.smithy_kind < 4, "The Fragua errante waits before the fight")
	var kind = s.smithy_kind
	s.gold = 0
	check(not s.can_accept_encounter(), "The forge needs the gold")
	s.gold = s.price(kind)
	var levels = [s.blade, s.wisps, s.armor, s.focus][kind]
	check(s.resolve_encounter(true) and s.gold == 0 and [s.blade, s.wisps, s.armor, s.focus][kind] == levels + 2, "Two levels for the price of one")

	# Persistence.
	s = elite(["burning", "swift"])
	s.burn_time = 1.5
	s.burn_dps = 4.0
	s.smithy_kind = 2
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Save with an affixed élite")
	check(restored.affixes == ["burning", "swift"] and is_equal_approx(restored.burn_time, 1.5) and restored.burn_dps == 4.0 and restored.smithy_kind == 2, "Affixes, the burn and the forge offer survive a reload")
	var good: Dictionary = s.snapshot()
	for bad in [{"affixes": ["flying"]}, {"affixes": ["burning", "swift", "thorny"]}, {"smithy_kind": 7}, {"relics": ["dragon"]}]:
		var data = good.duplicate(true)
		for key in bad:
			data[key] = bad[key]
		var f = FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		check(restored._read_save(SAVE) == null, "Invalid variety state rejected: %s" % [bad])
	var old = good.duplicate(true)
	for key in ["affixes", "burn_time", "burn_dps", "smithy_kind"]:
		old.erase(key)
	var f2 = FileAccess.open(SAVE, FileAccess.WRITE)
	f2.store_string(JSON.stringify(old))
	f2.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and restored.affixes.is_empty() and restored.burn_time == 0, "Older saves load élites without affixes")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("VARIETY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
