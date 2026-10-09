extends SceneTree
## Arsenal: equipment, rarities, traits, upgrades, salvage and masteries.
## godot --headless --path . --script tests/test_arsenal.gd
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_arsenal.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var s = State.new()
	s.rng.seed = 31
	s.restart()
	s.spawn_delay = 0
	s.wisps = 0
	s.ember_cooldown = 99999
	return s

func piece(s, base: String, rarity: int = 0, level: int = 0, quirk: String = "") -> Dictionary:
	var item = {"uid": s.next_item_uid, "base": base, "rarity": rarity, "level": level, "trait": quirk}
	s.next_item_uid += 1
	s.grant_item(item)
	return item

func _initialize() -> void:
	var s = fresh()
	check(s.armory.is_empty() and s.equipped.values().all(func(uid): return uid == -1) and s.scrap == 0, "A new save has an empty arsenal")

	# Generated pieces.
	var traits_ok = true
	var counts = [0, 0, 0, 0]
	for i in range(400):
		var item = s.make_item("boss")
		counts[item.rarity] += 1
		traits_ok = traits_ok and s.ITEMS.has(item.base) and (item.rarity >= 2 or item["trait"].is_empty()) and (item.rarity < 3 or not item["trait"].is_empty())
	check(traits_ok, "Only epic and legendary pieces carry a trait, and every legendary does")
	check(counts[0] > 0 and counts[1] > counts[3] and counts[3] > 0, "Boss rarities follow their weights: %s" % [counts])
	var elite_legendary = false
	for i in range(300):
		elite_legendary = elite_legendary or s.make_item("elite").rarity == 3
	check(not elite_legendary, "Elites never drop legendaries")

	# Equipping changes the stats.
	s = fresh()
	var click = s.click_damage()
	var sword = piece(s, "ash_sword", 1, 2)
	check(s.armory.size() == 1 and s.discoveries.has("item:ash_sword") and s.run_items == [sword.uid], "A found piece joins the arsenal and the collection")
	check(is_equal_approx(s.item_value(sword), s.ITEMS.ash_sword.base * s.RARITY_POWER[1] * (1.0 + s.LEVEL_STEP * 2)), "Value is base × rarity × level")
	check(s.click_damage() == click, "A stored piece does nothing until equipped")
	check(s.equip(sword.uid) and is_equal_approx(s.click_damage(), click * (1.0 + s.item_value(sword))), "An equipped weapon raises click damage")
	var blade = piece(s, "comet_blade", 0, 0)
	var crit = s.critical_chance()
	check(s.equip(blade.uid) and s.equipped.weapon == blade.uid and s.click_damage() == click, "One piece per slot: equipping replaces the previous one")
	check(is_equal_approx(s.critical_chance(), crit + s.ITEMS.comet_blade.base), "A comet blade adds critical chance")
	var hp = s.max_hp()
	var charm = piece(s, "moss_charm", 2, 0)
	s.equip(charm.uid)
	check(is_equal_approx(s.max_hp(), hp * (1.0 + s.ITEMS.moss_charm.base * s.RARITY_POWER[2])), "An amulet raises maximum health")
	s.hp = s.max_hp()
	check(s.unequip("amulet") and s.hp <= s.max_hp(), "Taking off an amulet never leaves health above the maximum")
	var scale = piece(s, "forge_scale", 3, 0)
	s.equip(scale.uid)
	s.attack_timer = s.attack_interval() - 0.01
	hp = s.hp
	var blow = s.enemy_damage()
	s.tick(0.02)
	check(is_equal_approx(hp - s.hp, blow * (1.0 - s.ITEMS.forge_scale.base * s.RARITY_POWER[3])), "Escama de forja reduces damage taken")
	var cooldown = s.burst_max_cooldown()
	var glass = piece(s, "black_hourglass", 1, 0)
	s.equip(glass.uid)
	check(is_equal_approx(s.burst_max_cooldown(), cooldown * (1.0 - s.ITEMS.black_hourglass.base * s.RARITY_POWER[1])), "Reloj de arena negra shortens Destello's recharge")
	var interval = s.wisp_interval()
	var bell = piece(s, "silver_bell", 0, 0)
	s.equip(bell.uid)
	check(is_equal_approx(s.wisp_interval(), interval / (1.0 + s.ITEMS.silver_bell.base)), "Campanilla de plata speeds up companions")
	check(s.item_stat_text(bell) == "+2,5% de velocidad de luceros" and s.item_stat_text(scale) == "−4,8% de daño recibido", "Stat texts show the current value: %s, %s" % [s.item_stat_text(bell), s.item_stat_text(scale)])

	# Upgrades and salvage.
	s = fresh()
	var item = piece(s, "split_coin", 0, 0)
	check(not s.upgrade_item(item.uid), "Upgrades need esquirlas")
	s.scrap = 1000
	var levels = 0
	while s.upgrade_item(item.uid):
		levels += 1
	check(item.level == s.RARITY_MAX_LEVEL[0] and levels == 4 and s.scrap == 1000 - (2 + 4 + 6 + 8), "Each level costs more and the rarity caps the level")
	check(s.achievements.has("smith"), "A piece at its maximum level earns Mano de herrero")
	s.equip(item.uid)
	check(not s.salvage(item.uid), "Equipped pieces cannot be salvaged")
	s.unequip("amulet")
	var value = s.salvage_value(item)
	var scrap = s.scrap
	check(s.salvage(item.uid) and s.scrap == scrap + value and s.armory.is_empty(), "Salvage returns esquirlas and removes the piece")
	check(value == 2 + int(4 * 2 * 0.5), "Salvage value counts rarity and level")
	s.armory.clear()
	for i in range(s.ARMORY_SIZE):
		piece(s, "ash_sword")
	scrap = s.scrap
	var extra = piece(s, "rune_spear", 3)
	check(s.armory.size() == s.ARMORY_SIZE and s.scrap == scrap + s.SALVAGE[3], "A full arsenal melts new pieces into esquirlas")
	check(s.achievements.has("legendary"), "Finding a legendary earns Leyenda forjada")

	# Masteries.
	s = fresh()
	check(not s.buy_mastery(0), "Masteries need esquirlas")
	s.scrap = 1000
	var burst = s.burst_damage()
	check(s.buy_mastery(0) and is_equal_approx(s.burst_damage(), burst * 1.08) and s.scrap == 1000 - s.MASTERIES[0].cost, "Destello ardiente raises Destello damage")
	check(s.mastery_cost(0) == s.MASTERIES[0].cost * 2, "The next level costs more")
	for i in range(10):
		s.buy_mastery(0)
	check(s.mastery("burst_power") == 5, "Masteries stop at their maximum")
	check(not s.buy_mastery(-1) and not s.buy_mastery(99), "Unknown masteries are rejected")
	var window = s.perfect_window()
	s.buy_mastery(2)
	check(is_equal_approx(s.perfect_window(), window + 0.04), "Guardia amplia widens the perfect parry")
	var riposte = s.riposte_power()
	s.buy_mastery(3)
	check(is_equal_approx(s.riposte_power(), riposte + 0.5), "Contraataque strengthens the riposte")
	var share = s.block_share()
	s.buy_mastery(4)
	check(is_equal_approx(s.block_share(), share - 0.05), "Guardia firme blocks more")
	var duration = s.weak_duration()
	var bonus = s.weak_bonus()
	s.buy_mastery(5)
	check(is_equal_approx(s.weak_duration(), duration + 0.25) and is_equal_approx(s.weak_bonus(), bonus + 0.2), "Ojo afilado lengthens and sharpens the weak point")

	# Traits.
	s = fresh()
	var steady = piece(s, "ash_sword", 3, 0, "steady")
	window = s.perfect_window()
	s.equip(steady.uid)
	check(is_equal_approx(s.perfect_window(), window + 0.1), "Pulso sereno widens the perfect parry")
	s = fresh()
	s.equip(piece(s, "ash_sword", 3, 0, "vampire").uid)
	s.hp = 50
	s.click_cooldown = 0
	s.weak_active = true
	s.weak_timer = 2.0
	s.strike_weak()
	s.tick(s.HIT_DELAY + 0.01)
	check(s.hp > 50, "Sed de brasas heals on a critical")
	s = fresh()
	s.equip(piece(s, "forge_scale", 3, 0, "thorns").uid)
	s.attack_timer = s.attack_interval() - 0.4
	var enemy = s.enemy_hp
	s.parry()
	s.tick(0.45)
	check(s.enemy_hp < enemy, "Espinas de obsidiana strikes back on a block")
	s = fresh()
	s.equip(piece(s, "wisp_lantern", 3, 0, "keen").uid)
	var waits = []
	for i in range(20):
		waits.append(s._weak_wait())
	check(waits.max() <= 5.0, "Ojo de halcón halves the wait between weak points")

	# Drops.
	s = fresh()
	s.room = 10
	s.spawn_enemy(false)
	s.spawn_delay = 0
	scrap = s.scrap
	s.damage_enemy(1e12)
	check(s.armory.size() == 1 and s.scrap == scrap + 1, "Every boss leaves a piece and esquirlas")
	var item_loot = false
	var scrap_loot = false
	for seed_value in range(80):
		s.rng.seed = seed_value
		for entry in s.roll_loot(1):
			item_loot = item_loot or (entry.kind == "item" and s.ITEMS.has(entry.item.base))
			scrap_loot = scrap_loot or (entry.kind == "scrap" and entry.amount == 6)
	check(item_loot and scrap_loot, "Chests can hold pieces and esquirlas")
	s = fresh()
	var count = s.armory.size()
	s.journey_phase = "chest"
	s.chest_tier = 0
	s._apply_loot({"kind": "item", "amount": 1, "item": s.make_item("wood")})
	check(s.armory.size() == count + 1, "A piece from a chest joins the arsenal")

	# Persistence.
	s = fresh()
	s.scrap = 77
	var a = piece(s, "rune_spear", 2, 3, "lucky")
	var b = piece(s, "silver_bell", 1, 1)
	s.equip(a.uid)
	s.equip(b.uid)
	s.masteries = {"riposte": 2}
	var restored = State.new()
	check(s.save_game(SAVE) and restored.load_game(SAVE, false), "Save with an arsenal")
	check(restored.armory == s.armory and restored.equipped == s.equipped and restored.scrap == 77 and restored.mastery("riposte") == 2 and restored.next_item_uid == s.next_item_uid, "The arsenal survives a reload")
	check(is_equal_approx(restored.burst_damage(), s.burst_damage()) and is_equal_approx(restored.wisp_interval(), s.wisp_interval()), "Equipped stats are the same after a reload")
	var good: Dictionary = s.snapshot()
	var bad_cases = [
		{"armory": [{"uid": 1, "base": "dragon", "rarity": 0, "level": 0, "trait": ""}]},
		{"armory": [{"uid": 1, "base": "ash_sword", "rarity": 0, "level": 9, "trait": ""}]},
		{"armory": [{"uid": 1, "base": "ash_sword", "rarity": 5, "level": 0, "trait": ""}]},
		{"armory": [{"uid": 1, "base": "ash_sword", "rarity": 0, "level": 0, "trait": "flight"}]},
		{"armory": [{"uid": 1, "base": "ash_sword", "rarity": 0, "level": 0, "trait": ""}, {"uid": 1, "base": "ash_sword", "rarity": 0, "level": 0, "trait": ""}]},
		{"equipped": {"weapon": b.uid, "talisman": -1, "amulet": -1}},
		{"equipped": {"weapon": 999, "talisman": -1, "amulet": -1}},
		{"masteries": {"riposte": 9}},
		{"masteries": {"flying": 1}},
		{"next_item_uid": 1}]
	for bad in bad_cases:
		var data = good.duplicate(true)
		for key in bad:
			data[key] = bad[key]
		var f = FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		check(restored._read_save(SAVE) == null, "Invalid arsenal rejected: %s" % [bad])
	var old = good.duplicate(true)
	for key in ["armory", "equipped", "masteries", "run_items", "scrap", "next_item_uid", "total_items"]:
		old.erase(key)
	var f2 = FileAccess.open(SAVE, FileAccess.WRITE)
	f2.store_string(JSON.stringify(old))
	f2.close()
	restored = State.new()
	check(restored.load_game(SAVE, false) and restored.armory.is_empty() and restored.scrap == 0 and restored.next_item_uid == 1, "Saves from before the arsenal load with an empty one")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("ARSENAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
