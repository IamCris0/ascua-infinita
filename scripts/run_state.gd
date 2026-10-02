extends RefCounted
## All progression rules live here, independently of presentation.

signal changed
signal struck(damage: float, critical: bool, automatic: bool)
signal event(text: String)
signal fallen
signal enemy_changed

const RELICS = [
	{"id": "fang", "name": "Colmillo de rubí", "tag": "OFENSIVA", "description": "+30% al daño de tus clics.", "color": "f77878"},
	{"id": "clock", "name": "Reloj sin horas", "tag": "AUTOMATIZACIÓN", "description": "+40% al daño de los luceros.", "color": "74d9c1"},
	{"id": "eye", "name": "Ojo del cometa", "tag": "PRECISIÓN", "description": "+12% de probabilidad crítica.", "color": "e8bd75"},
	{"id": "heart", "name": "Corazón de musgo", "tag": "SUPERVIVENCIA", "description": "+35 de vida máxima. Recuperas 35 de vida.", "color": "a3c978"},
	{"id": "coin", "name": "Moneda del olvido", "tag": "FORTUNA", "description": "+35% de oro en esta expedición.", "color": "e8bd75"},
	{"id": "ash", "name": "Ceniza hambrienta", "tag": "VAMPIRISMO", "description": "Recuperas 2 de vida al vencer un enemigo.", "color": "be99ea"},
	{"id": "storm", "name": "Frasco de tormenta", "tag": "DESTELLO", "description": "Destello recarga 20% más rápido.", "color": "82bcf5"}
]
const BIOMES = ["JARDÍN DE LAS CENIZAS", "CRIPTAS DEL ECO", "FORJA DEL ECLIPSE"]
const ENEMIES = ["Gelatina de hollín", "Lucero extraviado", "Centinela hueco"]
const SAVE_PATH = "user://ascua_save.json"

var rng = RandomNumberGenerator.new()
var room: int = 1
var gold: float = 0
var hp: float = 100
var enemy_hp: float = 24
var enemy_max: float = 24
var attack_timer: float = 0
var auto_timer: float = 0
var click_cooldown: float = 0
var burst_cooldown: float = 0
var combo: int = 0
var combo_time: float = 0
var blade: int = 0
var wisps: int = 0
var armor: int = 0
var relics: Array = []
var offers: Array = []
var essence: int = 0
var run_essence: int = 0
var legacy: Array = [0, 0, 0]
var best: int = 1
var total_kills: int = 0
var runs: int = 0
var dead: bool = false
var paused: bool = false
var muted: bool = false
var reduced_motion: bool = false
var save_error: String = ""
var offline_reward: float = 0

func _init() -> void:
	rng.randomize()

func count_relic(id: String) -> int:
	return relics.count(id)

func max_hp() -> float:
	return 100.0 + int(legacy[1]) * 20 + count_relic("heart") * 35 + armor * 15

func click_damage() -> float:
	return (5.0 + blade * 3.5 + int(legacy[0]) * 2) * (1.0 + count_relic("fang") * 0.3)

func auto_damage() -> float:
	return wisps * (2.5 + int(legacy[2]) * 1.0) * (1.0 + count_relic("clock") * 0.4)

func critical_chance() -> float:
	return minf(0.65, 0.08 + count_relic("eye") * 0.12)

func is_boss() -> bool:
	return room % 10 == 0

func biome() -> int:
	return int((room - 1) / 10.0) % 3

func enemy_kind() -> String:
	return "boss" if is_boss() else ["slime", "wisp", "sentinel"][(room - 1) % 3]

func enemy_name() -> String:
	return "EL REY SIN BRASA" if is_boss() else ENEMIES[(room - 1) % 3]

func attack_interval() -> float:
	return 3.4 if is_boss() else 4.8

func enemy_damage() -> float:
	return maxf(1, (5 + room * 1.35) * (1.7 if is_boss() else 1.0) - armor * 2)

func price(kind: int) -> int:
	var level: int = [blade, wisps, armor][kind]
	return int([12, 20, 24][kind] * pow(1.48, min(level, 100)))

func legacy_price(kind: int) -> int:
	return 5 + int(legacy[kind]) * 5

func active() -> bool:
	return not dead and not paused and offers.is_empty()

func tick(delta: float) -> void:
	if not active():
		return
	click_cooldown = maxf(0, click_cooldown - delta)
	burst_cooldown = maxf(0, burst_cooldown - delta)
	combo_time = maxf(0, combo_time - delta)
	if combo_time <= 0:
		combo = 0
	auto_timer += delta
	if auto_timer >= 1:
		auto_timer = fmod(auto_timer, 1.0)
		if auto_damage() > 0:
			damage_enemy(auto_damage(), false, true)
			if not active():
				return
	attack_timer += delta
	if attack_timer >= attack_interval():
		attack_timer = 0
		hp = maxf(0, hp - enemy_damage())
		event.emit("El enemigo golpea · −%d de vida" % int(enemy_damage()))
		if hp <= 0:
			finish_run()
	changed.emit()

func click() -> bool:
	if not active() or click_cooldown > 0:
		return false
	click_cooldown = 0.075
	combo = mini(20, combo + 1)
	combo_time = 1.5
	var critical = rng.randf() < critical_chance()
	var damage = click_damage() * (1 + combo * 0.015) * (2.0 if critical else 1.0)
	damage_enemy(damage, critical, false)
	return true

func burst() -> bool:
	if not active() or burst_cooldown > 0:
		return false
	burst_cooldown = 12 * pow(0.8, count_relic("storm"))
	damage_enemy(click_damage() * 8 + auto_damage() * 3, true, false)
	event.emit("DESTELLO · la llama despierta")
	return true

func damage_enemy(amount: float, critical: bool = false, automatic: bool = false) -> void:
	if not active():
		return
	enemy_hp = maxf(0, enemy_hp - amount)
	struck.emit(amount, critical, automatic)
	if enemy_hp <= 0:
		defeat_enemy()
	changed.emit()

func defeat_enemy() -> void:
	var reward = (8 + room * 3) * (1 + 0.35 * count_relic("coin")) * (3 if is_boss() else 1)
	gold += reward
	run_essence += 5 if is_boss() else 1
	total_kills += 1
	hp = minf(max_hp(), hp + 3 + count_relic("ash") * 2 + (20 if is_boss() else 0))
	event.emit("%s vencido · +%d oro" % [enemy_name(), int(reward)])
	var grant_relic = room % 5 == 0
	room += 1
	best = maxi(best, room)
	spawn_enemy()
	if grant_relic:
		var pool: Array = range(RELICS.size())
		offers.clear()
		for i in range(3):
			var pick = rng.randi_range(0, pool.size() - 1)
			offers.append(pool.pop_at(pick))

func spawn_enemy() -> void:
	enemy_max = (18 + room * 6) * pow(1.105, min(room - 1, 500)) * (3.5 if is_boss() else 1.0)
	enemy_hp = enemy_max
	attack_timer = 0
	enemy_changed.emit()

func choose_relic(index: int) -> bool:
	if not offers.has(index):
		return false
	var relic: Dictionary = RELICS[index]
	relics.append(relic.id)
	if relic.id == "heart":
		hp += 35
	offers.clear()
	event.emit("Reliquia obtenida · " + str(relic.name))
	changed.emit()
	return true

func buy(kind: int) -> bool:
	if kind < 0 or kind > 2 or not active() or gold < price(kind):
		return false
	gold -= price(kind)
	match kind:
		0: blade += 1
		1: wisps += 1
		2:
			armor += 1
			hp = minf(max_hp(), hp + 30)
	event.emit(["Filo mejorado", "Un lucero se une a ti", "Armadura reforzada · +30 vida"][kind])
	changed.emit()
	return true

func finish_run() -> void:
	if dead:
		return
	essence += run_essence
	run_essence = 0
	dead = true
	offers.clear()
	runs += 1
	fallen.emit()
	changed.emit()

func buy_legacy(kind: int) -> bool:
	if kind < 0 or kind > 2 or not dead or essence < legacy_price(kind):
		return false
	essence -= legacy_price(kind)
	legacy[kind] = int(legacy[kind]) + 1
	changed.emit()
	return true

func restart() -> void:
	room = 1
	gold = 0
	blade = 0
	wisps = 0
	armor = 0
	relics.clear()
	offers.clear()
	run_essence = 0
	hp = max_hp()
	dead = false
	paused = false
	attack_timer = 0
	auto_timer = 0
	click_cooldown = 0
	burst_cooldown = 0
	combo = 0
	combo_time = 0
	spawn_enemy()
	event.emit("Una nueva expedición. Tu legado permanece.")
	changed.emit()

func snapshot() -> Dictionary:
	return {"version": 1, "room": room, "gold": gold, "hp": hp, "enemy_hp": enemy_hp,
		"blade": blade, "wisps": wisps, "armor": armor, "relics": relics, "offers": offers,
		"essence": essence, "run_essence": run_essence, "legacy": legacy, "best": best,
		"total_kills": total_kills, "runs": runs, "dead": dead, "muted": muted,
		"reduced_motion": reduced_motion, "burst_cooldown": burst_cooldown,
		"attack_timer": attack_timer, "saved_at": Time.get_unix_time_from_system()}

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
	if not data is Dictionary or data.get("version") != 1:
		return null
	for key in ["room", "gold", "hp", "enemy_hp", "blade", "wisps", "armor", "essence", "run_essence", "best", "runs", "total_kills", "saved_at", "burst_cooldown", "attack_timer"]:
		if not data.has(key) or not (data[key] is float or data[key] is int) or not is_finite(float(data[key])) or float(data[key]) < 0:
			return null
	for key in ["dead", "muted", "reduced_motion"]:
		if not data.get(key) is bool:
			return null
	for key in ["legacy", "relics", "offers"]:
		if not data.get(key) is Array:
			return null
	if data.legacy.size() != 3 or data.room < 1 or data.room > 10000:
		return null
	for level in data.legacy:
		if not (level is float or level is int) or level < 0 or level > 100000:
			return null
	for offer in data.offers:
		if not (offer is float or offer is int) or offer < 0 or offer >= RELICS.size():
			return null
	for relic in data.relics:
		if not relic in ["fang", "clock", "eye", "heart", "coin", "ash", "storm"]:
			return null
	return data

func load_game(path: String = SAVE_PATH, allow_offline: bool = true) -> bool:
	var data = _read_save(path)
	if data == null:
		data = _read_save(path + ".bak")
	if data == null:
		return false
	for key in ["room", "gold", "blade", "wisps", "armor", "essence", "run_essence", "best", "runs", "total_kills", "dead", "muted", "reduced_motion", "burst_cooldown", "attack_timer"]:
		set(key, data[key])
	legacy = data.legacy.duplicate()
	relics = data.relics.duplicate()
	offers = data.offers.map(func(v): return int(v))
	spawn_enemy()
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
			gold += offline_reward
	paused = false
	return true
