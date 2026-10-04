extends RefCounted
## All progression rules live here, independently of presentation.

signal changed
signal struck(damage: float, critical: bool, automatic: bool)
signal event(text: String)
signal fallen
signal enemy_changed
signal enemy_defeated(kind: String, elite: bool, boss: bool)
signal hero_hit(damage: float, heavy: bool)
signal boss_charge_started
signal boss_interrupted
signal ember_spawned
signal ember_collected(kind: String, amount: float)
signal relic_offered
signal purchased(kind: int, count: int)

const SAVE_VERSION = 3
const SAVE_PATH = "user://ascua_save.json"
const RELICS = [
	{"id": "fang", "name": "Colmillo de rubí", "tag": "OFENSIVA", "description": "+30% al daño de tus clics.", "color": "f77878"},
	{"id": "clock", "name": "Reloj sin horas", "tag": "AUTOMATIZACIÓN", "description": "+40% al daño de los luceros.", "color": "74d9c1"},
	{"id": "eye", "name": "Ojo del cometa", "tag": "PRECISIÓN", "description": "+12% de probabilidad crítica.", "color": "e8bd75"},
	{"id": "heart", "name": "Corazón de musgo", "tag": "SUPERVIVENCIA", "description": "+35 de vida máxima. Recuperas 35 de vida.", "color": "a3c978"},
	{"id": "coin", "name": "Moneda del olvido", "tag": "FORTUNA", "description": "+35% de oro en esta expedición.", "color": "e8bd75"},
	{"id": "ash", "name": "Ceniza hambrienta", "tag": "VAMPIRISMO", "description": "Recuperas 4 de vida al vencer a un enemigo.", "color": "be99ea"},
	{"id": "storm", "name": "Frasco de tormenta", "tag": "DESTELLO", "description": "Destello recarga un 20% más rápido y golpea un 25% más fuerte.", "color": "82bcf5"}
]
const RELIC_IDS = ["fang", "clock", "eye", "heart", "coin", "ash", "storm"]
const UPGRADES = [
	{"name": "Filo de ascua", "description": "+3,5 daño por clic", "base": 15, "growth": 1.52},
	{"name": "Lucero guardián", "description": "Un lucero ataca solo: +4 daño / s", "base": 25, "growth": 1.55},
	{"name": "Piel de obsidiana", "description": "+15 vida máxima, cura 30 y bloquea 2 de daño", "base": 30, "growth": 1.58},
	{"name": "Ojo de brasa", "description": "+3% crítico y +10% daño crítico", "base": 60, "growth": 1.7}
]
const LEGACY = [
	{"name": "Brasa interior", "description": "+2 al daño por clic y +8% a todo tu daño", "base": 5, "step": 5},
	{"name": "Corazón eterno", "description": "+20 de vida máxima", "base": 5, "step": 5},
	{"name": "Pacto estelar", "description": "+1 de daño por cada lucero", "base": 5, "step": 5},
	{"name": "Fortuna heredada", "description": "+10% de oro obtenido", "base": 8, "step": 6},
	{"name": "Chispa temprana", "description": "Empiezas cada viaje con 30 de oro", "base": 6, "step": 6},
	{"name": "Tormenta contenida", "description": "Destello recarga un 6% más rápido", "base": 10, "step": 8}
]
const BIOMES = ["JARDÍN DE LAS CENIZAS", "CRIPTAS DEL ECO", "FORJA DEL ECLIPSE"]
const BIOME_RULES = [
	"Las ruinas guardan silencio. Sin efectos de ambiente.",
	"Eco: los enemigos recuperan vida si dejas de golpearlos.",
	"Calor: +25% de oro, pero los enemigos golpean un 15% más fuerte."
]
const ENEMY_NAMES = [
	["Gelatina de hollín", "Lucero extraviado", "Centinela hueco"],
	["Gelatina del eco", "Lucero sepulcral", "Centinela de cripta"],
	["Gelatina de escoria", "Lucero de brasa", "Centinela forjado"]
]
const BOSS_TITLES = ["SEÑOR DEL JARDÍN", "SEÑOR DE LAS CRIPTAS", "SEÑOR DE LA FORJA"]
const EMBER_KINDS = ["gold", "fury", "heal", "spark"]
const SPAWN_DELAY = 0.35
const BOSS_INTRO = 1.6
const CHARGE_TIME = 3.0
const STORM_LEGACY_MAX = 10
const CLICK_INTERVAL = 0.3

var rng = RandomNumberGenerator.new()
# Expedition
var room: int = 1
var gold: float = 0
var hp: float = 100
var enemy_hp: float = 24
var enemy_max: float = 24
var enemy_elite: bool = false
var attack_timer: float = 0
var auto_timer: float = 0
var click_cooldown: float = 0
var burst_cooldown: float = 0
var combo: int = 0
var combo_time: float = 0
var idle_time: float = 0
var spawn_delay: float = 0
var stun_time: float = 0
var boss_attacks: int = 0
var charging: bool = false
var charge_timer: float = 0
var fury_time: float = 0
var ember_active: bool = false
var ember_timer: float = 0
var ember_cooldown: float = 40
var ember_pos: Vector2 = Vector2(0.5, 0.4)
var blade: int = 0
var wisps: int = 0
var armor: int = 0
var focus: int = 0
var relics: Array = []
var offers: Array = []
var journey_phase: String = ""
var encounter_kind: String = ""
var altar_pacts: int = 0
var run_essence: int = 0
var run_kills: int = 0
var run_gold: float = 0
var run_time: float = 0
var run_bosses: int = 0
# Permanent
var essence: int = 0
var legacy: Array = [0, 0, 0, 0, 0, 0]
var best: int = 1
var total_kills: int = 0
var total_bosses: int = 0
var total_elites: int = 0
var total_embers: int = 0
var total_gold: float = 0
var runs: int = 0
var dead: bool = false
var paused: bool = false
# Preferences
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var reduced_motion: bool = false
var screen_shake: bool = true
var show_numbers: bool = true
var fullscreen: bool = false
var save_error: String = ""
var offline_reward: float = 0

func _init() -> void:
	rng.randomize()

# ---------------------------------------------------------------- derived stats
func count_relic(id: String) -> int:
	return relics.count(id)

func legacy_level(kind: int) -> int:
	return int(legacy[kind]) if kind < legacy.size() else 0

func max_hp() -> float:
	return 120.0 + legacy_level(1) * 20 + count_relic("heart") * 35 + armor * 15

func power_multiplier() -> float:
	return (1.0 + legacy_level(0) * 0.08) * (1.0 + altar_pacts * 0.2)

func click_damage() -> float:
	var base = (5.0 + blade * 3.5 + legacy_level(0) * 2) * (1.0 + count_relic("fang") * 0.3) * power_multiplier()
	return base * (2.0 if fury_time > 0 else 1.0)

func wisp_damage() -> float:
	return (4.0 + legacy_level(2) * 1.0) * (1.0 + count_relic("clock") * 0.4) * power_multiplier()

func auto_damage() -> float:
	return wisps * wisp_damage()

func critical_chance() -> float:
	return minf(0.65, 0.08 + count_relic("eye") * 0.12 + focus * 0.03)

func critical_multiplier() -> float:
	return 2.0 + focus * 0.1

func gold_multiplier() -> float:
	return (1.0 + 0.35 * count_relic("coin")) * (1.0 + legacy_level(3) * 0.1) * (1.25 if biome() == 2 else 1.0)

func burst_damage() -> float:
	return (click_damage() * 8 + auto_damage() * 3) * (1.0 + count_relic("storm") * 0.25)

func burst_max_cooldown() -> float:
	return 12.0 * pow(0.8, count_relic("storm")) * pow(0.94, mini(legacy_level(5), STORM_LEGACY_MAX))

func legacy_maxed(kind: int) -> bool:
	return kind == 5 and legacy_level(kind) >= STORM_LEGACY_MAX

func is_boss() -> bool:
	return room % 10 == 0

func biome() -> int:
	return int((room - 1) / 10.0) % 3

func cycle() -> int:
	return int((room - 1) / 30.0)

func enemy_kind() -> String:
	return "boss" if is_boss() else ["slime", "wisp", "sentinel"][(room - 1) % 3]

func enemy_name() -> String:
	if is_boss():
		return "EL REY SIN BRASA"
	return ("Élite · " if enemy_elite else "") + ENEMY_NAMES[biome()][(room - 1) % 3]

func boss_title() -> String:
	return BOSS_TITLES[biome()]

func attack_interval() -> float:
	if is_boss():
		return 4.0
	return [5.6, 4.8, 6.6][(room - 1) % 3]

func enemy_damage() -> float:
	var raw = (5 + room * 1.35) * (1.7 if is_boss() else 1.0) * (1.3 if enemy_elite else 1.0) * (1.15 if biome() == 2 else 1.0)
	raw *= [1.0, 0.85, 1.25][(room - 1) % 3] if not is_boss() else 1.0
	return maxf(1, raw - armor * 2)

func heavy_damage() -> float:
	return enemy_damage() * 3.0

func kill_reward() -> float:
	return (16 + room * 6.5) * gold_multiplier() * (3.0 if is_boss() else 1.0) * (2.5 if enemy_elite else 1.0)

func price(kind: int) -> int:
	var level: int = [blade, wisps, armor, focus][kind]
	return int(UPGRADES[kind].base * pow(UPGRADES[kind].growth, mini(level, 120)))

func bulk_price(kind: int, count: int) -> float:
	var level: int = [blade, wisps, armor, focus][kind]
	var total = 0.0
	for i in range(count):
		total += int(UPGRADES[kind].base * pow(UPGRADES[kind].growth, mini(level + i, 120)))
	return total

func affordable(kind: int, limit: int = 1000) -> int:
	var level: int = [blade, wisps, armor, focus][kind]
	var total = 0.0
	var count = 0
	while count < limit:
		var step = int(UPGRADES[kind].base * pow(UPGRADES[kind].growth, mini(level + count, 120)))
		if total + step > gold:
			break
		total += step
		count += 1
	return count

func legacy_price(kind: int) -> int:
	return LEGACY[kind].base + legacy_level(kind) * LEGACY[kind].step

func active() -> bool:
	return not dead and not paused and offers.is_empty() and journey_phase.is_empty()

func can_strike() -> bool:
	return active() and spawn_delay <= 0

func charge_progress() -> float:
	return 1.0 - charge_timer / CHARGE_TIME if charging else 0.0

func next_is_heavy() -> bool:
	return is_boss() and boss_attacks % 3 == 2

# ---------------------------------------------------------------- simulation
func tick(delta: float) -> void:
	if not active():
		return
	run_time += delta
	click_cooldown = maxf(0, click_cooldown - delta)
	burst_cooldown = maxf(0, burst_cooldown - delta)
	fury_time = maxf(0, fury_time - delta)
	combo_time = maxf(0, combo_time - delta)
	if combo_time <= 0:
		combo = 0
	_tick_ember(delta)
	if spawn_delay > 0:
		spawn_delay = maxf(0, spawn_delay - delta)
		changed.emit()
		return
	idle_time += delta
	if biome() == 1 and idle_time > 2.0 and enemy_hp < enemy_max:
		enemy_hp = minf(enemy_max, enemy_hp + enemy_max * 0.03 * delta)
	auto_timer += delta
	if auto_timer >= 1:
		auto_timer = fmod(auto_timer, 1.0)
		if auto_damage() > 0:
			damage_enemy(auto_damage(), false, true)
			if not active() or spawn_delay > 0:
				changed.emit()
				return
	if stun_time > 0:
		stun_time = maxf(0, stun_time - delta)
	elif charging:
		charge_timer = maxf(0, charge_timer - delta)
		if charge_timer <= 0:
			charging = false
			boss_attacks += 1
			_hit_hero(heavy_damage(), true)
	else:
		attack_timer += delta
		if attack_timer >= attack_interval():
			attack_timer = 0
			if next_is_heavy():
				charging = true
				charge_timer = CHARGE_TIME
				event.emit("¡El Rey reúne su brasa! Interrúmpelo con Destello.")
				boss_charge_started.emit()
			else:
				boss_attacks += 1
				_hit_hero(enemy_damage(), false)
	changed.emit()

func _hit_hero(amount: float, heavy: bool) -> void:
	hp = maxf(0, hp - amount)
	hero_hit.emit(amount, heavy)
	event.emit(("Brasa del Rey" if heavy else "El enemigo golpea") + " · −%d de vida" % int(amount))
	if hp <= 0:
		finish_run()

func _tick_ember(delta: float) -> void:
	if ember_active:
		ember_timer = maxf(0, ember_timer - delta)
		if ember_timer <= 0:
			ember_active = false
			ember_cooldown = rng.randf_range(35, 70)
		return
	if room < 3:
		return
	ember_cooldown = maxf(0.0, ember_cooldown - delta)
	if ember_cooldown <= 0:
		ember_active = true
		ember_timer = 8.0
		ember_pos = Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.18, 0.5))
		ember_spawned.emit()

func collect_ember() -> String:
	if not ember_active or not active():
		return ""
	ember_active = false
	ember_cooldown = rng.randf_range(35, 70)
	total_embers += 1
	var kind: String = EMBER_KINDS[rng.randi_range(0, EMBER_KINDS.size() - 1)]
	if kind == "heal" and hp >= max_hp() * 0.95:
		kind = "gold"
	if kind == "spark" and burst_cooldown <= 0:
		kind = "fury"
	var amount := 0.0
	match kind:
		"gold":
			amount = kill_reward() * 4
			_gain_gold(amount)
			event.emit("Ascua errante · +%d oro" % int(amount))
		"fury":
			fury_time = 12.0
			amount = 12
			event.emit("Ascua errante · ¡Furia! Doble daño de clic durante 12 s")
		"heal":
			amount = minf(max_hp() - hp, max_hp() * 0.35)
			hp += amount
			event.emit("Ascua errante · +%d de vida" % int(amount))
		"spark":
			burst_cooldown = 0
			event.emit("Ascua errante · Destello listo")
	ember_collected.emit(kind, amount)
	changed.emit()
	return kind

func click() -> bool:
	if not can_strike() or click_cooldown > 0:
		return false
	click_cooldown = CLICK_INTERVAL
	combo = mini(20, combo + 1)
	combo_time = 1.5
	var critical = rng.randf() < critical_chance()
	var damage = click_damage() * (1 + combo * 0.015) * (critical_multiplier() if critical else 1.0)
	damage_enemy(damage, critical, false)
	return true

func burst() -> bool:
	if not can_strike() or burst_cooldown > 0:
		return false
	burst_cooldown = burst_max_cooldown()
	var damage = burst_damage()
	if charging:
		charging = false
		boss_attacks += 1
		stun_time = 2.0
		attack_timer = 0
		damage *= 1.5
		event.emit("¡INTERRUMPIDO! El Rey queda aturdido")
		boss_interrupted.emit()
	else:
		event.emit("DESTELLO · la llama despierta")
	damage_enemy(damage, true, false)
	return true

func damage_enemy(amount: float, critical: bool = false, automatic: bool = false) -> void:
	if not active():
		return
	idle_time = 0
	enemy_hp = maxf(0, enemy_hp - amount)
	struck.emit(amount, critical, automatic)
	if enemy_hp <= 0:
		defeat_enemy()
	changed.emit()

func _gain_gold(amount: float) -> void:
	gold += amount
	run_gold += amount
	total_gold += amount

func defeat_enemy() -> void:
	var boss = is_boss()
	var reward = kill_reward()
	_gain_gold(reward)
	var depth = int(room / 10.0)
	run_essence += (5 + depth * 2 if boss else 1 + int(room / 15.0)) + (1 if enemy_elite else 0)
	total_kills += 1
	run_kills += 1
	if boss:
		total_bosses += 1
		run_bosses += 1
	if enemy_elite:
		total_elites += 1
	hp = minf(max_hp(), hp + 4 + count_relic("ash") * 4 + (25 if boss else 0))
	enemy_defeated.emit(enemy_kind(), enemy_elite, boss)
	event.emit("%s vencido · +%d oro" % [enemy_name().capitalize() if boss else enemy_name(), int(reward)])
	var grant_relic = room % 5 == 0
	room += 1
	best = maxi(best, room)
	spawn_enemy()
	if grant_relic:
		journey_phase = "route"
		encounter_kind = ["shrine", "merchant", "altar"][rng.randi_range(0, 2)]
		var pool: Array = range(RELICS.size())
		offers.clear()
		for i in range(3):
			var pick = rng.randi_range(0, pool.size() - 1)
			offers.append(pool.pop_at(pick))
		relic_offered.emit()

func spawn_enemy(roll_elite: bool = true) -> void:
	if roll_elite:
		enemy_elite = not is_boss() and room >= 6 and rng.randf() < 0.12
	enemy_max = (45 + room * 13) * pow(1.1, mini(room - 1, 500)) * (3.5 if is_boss() else 1.0) * (2.2 if enemy_elite else 1.0)
	enemy_max *= [1.0, 0.85, 1.3][(room - 1) % 3] if not is_boss() else 1.0
	enemy_hp = enemy_max
	attack_timer = 0
	charging = false
	charge_timer = 0
	stun_time = 0
	boss_attacks = 0
	idle_time = 0
	spawn_delay = BOSS_INTRO if is_boss() else SPAWN_DELAY
	enemy_changed.emit()

func choose_relic(index: int) -> bool:
	if not offers.has(index):
		return false
	var relic: Dictionary = RELICS[index]
	relics.append(relic.id)
	if relic.id == "heart":
		hp = minf(max_hp(), hp + 35)
	offers.clear()
	event.emit("Reliquia obtenida · " + str(relic.name))
	changed.emit()
	return true

# Routes are resolved only after the relic choice. Both decisions suspend combat.
func choose_route(index: int) -> bool:
	if journey_phase != "route" or not offers.is_empty() or dead or paused or index < 0 or index > 2:
		return false
	journey_phase = "event" if index == 2 else ""
	enemy_elite = index == 1
	spawn_enemy(false)
	if index == 0:
		hp = minf(max_hp(), hp + max_hp() * 0.2)
		event.emit("Sendero tranquilo · recuperas hasta un 20% de vida. Siguiente rival sin élite.")
	elif index == 1:
		event.emit("Desafío élite · más peligro a cambio de oro y ascuas.")
	if index != 2:
		encounter_kind = ""
	changed.emit()
	return true

func encounter_name() -> String:
	return {"shrine": "Santuario de la brasa", "merchant": "Mercader de cenizas", "altar": "Altar del eclipse"}.get(encounter_kind, "Encuentro")

func encounter_cost() -> int:
	return maxi(1, int(price(1) * 0.8)) if encounter_kind == "merchant" else int(ceil(max_hp() * 0.25))

func can_accept_encounter() -> bool:
	if journey_phase != "event" or dead or paused:
		return false
	match encounter_kind:
		"shrine": return true
		"merchant": return gold >= encounter_cost()
		"altar": return hp > encounter_cost()
	return false

func resolve_encounter(accept: bool) -> bool:
	if journey_phase != "event" or dead or paused or (accept and not can_accept_encounter()):
		return false
	if accept:
		match encounter_kind:
			"shrine": hp = minf(max_hp(), hp + max_hp() * 0.45)
			"merchant":
				gold -= encounter_cost()
				wisps += 1
			"altar":
				hp -= encounter_cost()
				altar_pacts += 1
		event.emit(encounter_name() + " · trato completado")
	else:
		event.emit(encounter_name() + " · sigues tu camino")
	journey_phase = ""
	encounter_kind = ""
	changed.emit()
	return true

func buy(kind: int, count: int = 1) -> int:
	if kind < 0 or kind >= UPGRADES.size() or not active() or count < 1:
		return 0
	var bought := 0
	while bought < count and gold >= price(kind):
		gold -= price(kind)
		match kind:
			0: blade += 1
			1: wisps += 1
			2:
				armor += 1
				hp = minf(max_hp(), hp + 30)
			3: focus += 1
		bought += 1
	if bought > 0:
		var names = ["Filo mejorado", "Un lucero se une a ti", "Armadura reforzada · +30 vida", "Tu mirada arde · más críticos"]
		event.emit(names[kind] + (" ×%d" % bought if bought > 1 else ""))
		purchased.emit(kind, bought)
		changed.emit()
	return bought

func finish_run() -> void:
	if dead:
		return
	essence += run_essence
	dead = true
	charging = false
	ember_active = false
	offers.clear()
	journey_phase = ""
	encounter_kind = ""
	runs += 1
	fallen.emit()
	changed.emit()

func buy_legacy(kind: int) -> bool:
	if kind < 0 or kind >= LEGACY.size() or not dead or legacy_maxed(kind) or essence < legacy_price(kind):
		return false
	essence -= legacy_price(kind)
	legacy[kind] = legacy_level(kind) + 1
	changed.emit()
	return true

func restart() -> void:
	room = 1
	gold = legacy_level(4) * 30.0
	blade = 0
	wisps = 1
	armor = 0
	focus = 0
	relics.clear()
	offers.clear()
	journey_phase = ""
	encounter_kind = ""
	altar_pacts = 0
	run_essence = 0
	run_kills = 0
	run_gold = 0
	run_time = 0
	run_bosses = 0
	hp = max_hp()
	dead = false
	paused = false
	attack_timer = 0
	auto_timer = 0
	click_cooldown = 0
	burst_cooldown = 0
	fury_time = 0
	combo = 0
	combo_time = 0
	ember_active = false
	ember_cooldown = 40
	spawn_enemy()
	event.emit("Una nueva expedición. Tu legado permanece.")
	changed.emit()

# ---------------------------------------------------------------- persistence
const NUMBER_KEYS = ["room", "gold", "hp", "enemy_hp", "blade", "wisps", "armor", "focus", "essence", "run_essence",
	"best", "runs", "total_kills", "total_bosses", "total_elites", "total_embers", "total_gold", "saved_at",
	"burst_cooldown", "attack_timer", "run_kills", "run_gold", "run_time", "run_bosses", "boss_attacks",
	"master_volume", "music_volume", "sfx_volume", "ember_cooldown", "altar_pacts"]
const BOOL_KEYS = ["dead", "reduced_motion", "screen_shake", "show_numbers", "fullscreen", "enemy_elite"]
# Older version 1/2 saves omit these fields. Their neutral defaults preserve
# the previous load behavior; new saves resume the exact combat phase.
const COMBAT_DEFAULTS = {"auto_timer": 0.0, "click_cooldown": 0.0, "combo": 0,
	"combo_time": 0.0, "idle_time": 0.0, "spawn_delay": 0.0, "stun_time": 0.0,
	"charging": false, "charge_timer": 0.0, "fury_time": 0.0,
	"ember_active": false, "ember_timer": 0.0}
const COMBAT_LIMITS = {"auto_timer": 1.0, "click_cooldown": CLICK_INTERVAL, "combo": 20,
	"combo_time": 1.5, "spawn_delay": BOSS_INTRO, "stun_time": 2.0,
	"charge_timer": CHARGE_TIME, "fury_time": 12.0, "ember_timer": 8.0}

func snapshot() -> Dictionary:
	var data := {"version": SAVE_VERSION, "relics": relics, "offers": offers, "legacy": legacy,
		"saved_at": Time.get_unix_time_from_system()}
	for key in NUMBER_KEYS:
		if key != "saved_at":
			data[key] = get(key)
	for key in BOOL_KEYS:
		data[key] = get(key)
	for key in COMBAT_DEFAULTS:
		data[key] = get(key)
	data.ember_pos = [ember_pos.x, ember_pos.y]
	data.journey_phase = journey_phase
	data.encounter_kind = encounter_kind
	return data

func save_game(path: String = SAVE_PATH) -> bool:
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		save_error = "No se pudo guardar la partida."
		return false
	f.store_string(JSON.stringify(snapshot()))
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var error = DirAccess.rename_absolute(path + ".tmp", path)
	save_error = "" if error == OK else "No se pudo completar el guardado."
	return error == OK

static func _migrate(data: Dictionary) -> Dictionary:
	if data.get("version") in [1, 2]:
		data.journey_phase = ""
		data.encounter_kind = ""
		data.altar_pacts = 0
	# Version 1 had three legacy upgrades, a single mute flag and no run statistics.
	if data.get("version") == 1:
		var muted = data.get("muted", false)
		data.master_volume = 0.0 if muted is bool and muted else 0.8
		data.music_volume = 0.7
		data.sfx_volume = 0.8
		for key in ["focus", "total_bosses", "total_elites", "total_embers", "total_gold", "run_kills", "run_gold", "run_time", "run_bosses", "boss_attacks"]:
			data[key] = 0
		data.ember_cooldown = 40
		for key in ["screen_shake", "show_numbers"]:
			data[key] = true
		data.fullscreen = false
		data.enemy_elite = false
		data.version = SAVE_VERSION
	if data.get("legacy") is Array:
		while data.legacy.size() < LEGACY.size():
			data.legacy.append(0)
	for key in COMBAT_DEFAULTS:
		if not data.has(key):
			data[key] = COMBAT_DEFAULTS[key]
	if not data.has("ember_pos"):
		data.ember_pos = [0.5, 0.4]
	return data

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parser = JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		return null
	var data = parser.data
	if not data is Dictionary or not data.get("version") in [1, 2, 3, 1.0, 2.0, 3.0]:
		return null
	data.version = int(data.version)
	data = _migrate(data)
	if not data.get("journey_phase") in ["", "route", "event"] or not data.get("encounter_kind") in ["", "shrine", "merchant", "altar"]:
		return null
	if data.journey_phase.is_empty() != data.encounter_kind.is_empty():
		return null
	for key in NUMBER_KEYS:
		if not data.has(key) or not (data[key] is float or data[key] is int) or not is_finite(float(data[key])) or float(data[key]) < 0:
			return null
	for key in BOOL_KEYS:
		if not data.get(key) is bool:
			return null
	for key in COMBAT_DEFAULTS:
		var value = data[key]
		if COMBAT_DEFAULTS[key] is bool:
			if not value is bool:
				return null
		else:
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0:
				return null
			if COMBAT_LIMITS.has(key) and value > COMBAT_LIMITS[key]:
				return null
			if COMBAT_DEFAULTS[key] is int and value != floor(value):
				return null
	if not data.ember_pos is Array or data.ember_pos.size() != 2:
		return null
	for coordinate in data.ember_pos:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or coordinate < 0 or coordinate > 1:
			return null
	for key in ["legacy", "relics", "offers"]:
		if not data.get(key) is Array:
			return null
	if data.altar_pacts != floor(data.altar_pacts) or data.altar_pacts > 10000:
		return null
	if data.journey_phase == "event" and not data.offers.is_empty():
		return null
	if not data.journey_phase.is_empty() and (data.dead or int(data.room) <= 1 or (int(data.room) - 1) % 5 != 0):
		return null
	if data.legacy.size() != LEGACY.size() or data.room < 1 or data.room > 10000:
		return null
	for level in data.legacy:
		if not (level is float or level is int) or level < 0 or level > 100000:
			return null
	for offer in data.offers:
		if not (offer is float or offer is int) or offer < 0 or offer >= RELICS.size():
			return null
	for relic in data.relics:
		if not relic in RELIC_IDS:
			return null
	return data

func load_game(path: String = SAVE_PATH, allow_offline: bool = true) -> bool:
	var data = _read_save(path)
	if data == null:
		data = _read_save(path + ".bak")
	if data == null:
		return false
	for key in NUMBER_KEYS:
		if key in ["saved_at", "enemy_hp", "hp", "attack_timer"]:
			continue
		if typeof(get(key)) == TYPE_INT:
			set(key, int(data[key]))
		else:
			set(key, float(data[key]))
	for key in BOOL_KEYS:
		set(key, data[key])
	master_volume = clampf(master_volume, 0, 1)
	music_volume = clampf(music_volume, 0, 1)
	sfx_volume = clampf(sfx_volume, 0, 1)
	legacy = data.legacy.map(func(v): return int(v))
	relics = data.relics.duplicate()
	offers = data.offers.map(func(v): return int(v))
	journey_phase = data.journey_phase
	encounter_kind = data.encounter_kind
	var boss_count = boss_attacks
	spawn_enemy(false)
	boss_attacks = boss_count
	for key in COMBAT_DEFAULTS:
		set(key, int(data[key]) if COMBAT_DEFAULTS[key] is int else data[key])
	ember_pos = Vector2(float(data.ember_pos[0]), float(data.ember_pos[1]))
	enemy_hp = clampf(data.enemy_hp, 0.01, enemy_max)
	attack_timer = clampf(data.attack_timer, 0, attack_interval())
	hp = clampf(data.hp, 0, max_hp())
	if hp <= 0 and not dead:
		finish_run()
	offline_reward = 0
	if allow_offline and not dead and wisps > 0:
		var elapsed = clampf(Time.get_unix_time_from_system() - float(data.saved_at), 0, 4 * 3600)
		if elapsed >= 60:
			offline_reward = floor(elapsed / 60) * wisps * 2
			_gain_gold(offline_reward)
	paused = false
	return true

func has_run() -> bool:
	return not dead
