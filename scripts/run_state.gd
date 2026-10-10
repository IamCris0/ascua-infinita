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
signal shield_broken
signal armor_broken
signal last_breath
signal achievement_unlocked(id: String)
signal echo_strike
signal attack_started
signal burst_released(interrupted: bool)
signal parry_started
signal parried(full: bool)
signal weak_appeared
signal weak_struck
signal node_entered(node: String)
signal chest_opened(tier: int, loot: Array)
signal wheel_spun(index: int)
signal item_found(item: Dictionary)
signal bearer_unlocked(id: String)
signal walled
signal fortune(amount: float)
signal mission_completed(text: String)
signal thorned(amount: float)

const SAVE_VERSION = 3
const SAVE_PATH = "user://ascua_save.json"
const RELICS = [
	{"id": "fang", "name": "Colmillo de rubí", "tag": "OFENSIVA", "description": "+30% al daño de tus clics.", "color": "f77878"},
	{"id": "clock", "name": "Reloj sin horas", "tag": "AUTOMATIZACIÓN", "description": "+40% al daño de los luceros.", "color": "74d9c1"},
	{"id": "eye", "name": "Ojo del cometa", "tag": "PRECISIÓN", "description": "+12% de probabilidad crítica.", "color": "e8bd75"},
	{"id": "heart", "name": "Corazón de musgo", "tag": "SUPERVIVENCIA", "description": "+35 de vida máxima. Recuperas 35 de vida.", "color": "a3c978"},
	{"id": "coin", "name": "Moneda del olvido", "tag": "FORTUNA", "description": "+35% de oro en esta expedición.", "color": "e8bd75"},
	{"id": "ash", "name": "Ceniza hambrienta", "tag": "VAMPIRISMO", "description": "Recuperas 4 de vida al vencer a un enemigo.", "color": "be99ea"},
	{"id": "storm", "name": "Frasco de tormenta", "tag": "DESTELLO", "description": "Destello recarga un 20% más rápido y golpea un 25% más fuerte.", "color": "82bcf5"},
	{"id": "horn", "name": "Cuerno de guerra", "tag": "CAZA MAYOR", "description": "+30% de daño contra élites y jefes.", "color": "e8d6a8"},
	{"id": "frost", "name": "Escudo de escarcha", "tag": "GUARDIA", "description": "La parada perfecta aturde 0,6 s más y el bloqueo detiene un 15% más.", "color": "9fd8ff"},
	{"id": "tear", "name": "Lágrima de fénix", "tag": "REGENERACIÓN", "description": "Recuperas un 0,5% de tu vida máxima por segundo.", "color": "ff9a4a"},
	{"id": "lens", "name": "Lente de cazador", "tag": "PUNTO DÉBIL", "description": "Los puntos débiles aparecen un 40% más a menudo y duran 1 s más.", "color": "7fe0bf"},
	{"id": "bag", "name": "Bolsa sin fondo", "tag": "BOTÍN", "description": "Cada cofre trae una recompensa más.", "color": "c48cf5"}
]
const SYNERGIES = [
	{"id": "precision", "pair": ["fang", "eye"], "name": "Filo del cometa", "description": "Cada crítico manual que impacta reduce 0,4 s la recarga de Destello."},
	{"id": "chorus", "pair": ["clock", "coin"], "name": "Coro dorado", "description": "Tras 2 s sin atacar manualmente, los luceros hacen un 30% más de daño. Destello no rompe el coro."},
	{"id": "stormcall", "pair": ["storm", "eye"], "name": "Tormenta certera", "description": "Interrumpir una canalización con Destello reduce un 25% su nueva recarga."},
	{"id": "shelter", "pair": ["heart", "ash"], "name": "Refugio de musgo", "description": "Vencer a un enemigo protege del 40% del siguiente golpe recibido. No acumula cargas."},
	{"id": "hunter", "pair": ["horn", "lens"], "name": "Cazador implacable", "description": "Acertar el punto débil de un élite o un jefe adelanta 3 s Destello."},
	{"id": "frostfire", "pair": ["frost", "tear"], "name": "Hielo y llama", "description": "Cada parada perfecta te cura un 5% de tu vida máxima."},
	{"id": "deep_pockets", "pair": ["bag", "coin"], "name": "Fortuna sin fondo", "description": "Los cofres del mapa nunca son de madera."}
]
const RELIC_IDS = ["fang", "clock", "eye", "heart", "coin", "ash", "storm", "horn", "frost", "tear", "lens", "bag"]
# Élites always carry an affix; a duel rival carries two. Names agree with
# "élite", which is feminine.
const AFFIX_IDS = ["burning", "armored", "swift", "vampiric", "thorny"]
const AFFIXES = {
	"burning": {"name": "ardiente", "hint": "Ardiente: sus golpes queman 3 s · párale", "color": "ff8a3d"},
	"armored": {"name": "acorazada", "hint": "Acorazada: −40% de daño hasta media vida", "color": "aab6c1"},
	"swift": {"name": "veloz", "hint": "Veloz: ataca un 35% más rápido", "color": "ffe38a"},
	"vampiric": {"name": "vampírica", "hint": "Vampírica: se cura al golpearte", "color": "e0645a"},
	"thorny": {"name": "espinosa", "hint": "Espinosa: tus clics te hieren · usa luceros", "color": "6fcf7e"}}
const BURN_TIME = 3.0
const UPGRADES = [
	{"name": "Filo de ascua", "description": "+3,5 daño por clic", "base": 15, "growth": 1.52},
	{"name": "Lucero guardián", "description": "+1 lucero que ataca solo", "base": 25, "growth": 1.55},
	{"name": "Piel de obsidiana", "description": "+15 vida y bloquea 2", "base": 30, "growth": 1.58},
	{"name": "Ojo de brasa", "description": "+3% crítico, +10% al crítico", "base": 60, "growth": 1.7}
]
# Constelación del Legado. Indices 0-5 are the original six upgrades and keep
# their saved positions; requirements only gate buying, never owned levels.
# Branches: "" shared, "filo" clicks, "luceros" companions, "brasa" survival.
# Brasa interior raises all damage, so it is shared: the Filo nodes grow from it.
const LEGACY = [
	{"name": "Brasa interior", "description": "+2 al daño por clic y +8% a todo tu daño", "base": 5, "step": 5, "max": 20, "branch": "", "requires": []},
	{"name": "Corazón eterno", "description": "+20 de vida máxima", "base": 5, "step": 5, "max": 20, "branch": "brasa", "requires": []},
	{"name": "Pacto estelar", "description": "+1 de daño por cada lucero", "base": 5, "step": 5, "max": 20, "branch": "luceros", "requires": []},
	{"name": "Fortuna heredada", "description": "+10% de oro obtenido", "base": 8, "step": 6, "max": 15, "branch": "", "requires": []},
	{"name": "Chispa temprana", "description": "Empiezas cada viaje con 30 de oro", "base": 6, "step": 6, "max": 10, "branch": "", "requires": []},
	{"name": "Tormenta contenida", "description": "Destello recarga un 6% más rápido", "base": 10, "step": 8, "max": 10, "branch": "brasa", "requires": [[1, 3]]},
	{"name": "Ojo templado", "description": "+2% de probabilidad crítica", "base": 12, "step": 8, "max": 5, "branch": "filo", "requires": [[0, 3]]},
	{"name": "Cadena larga", "description": "+5 al tope de la cadena de golpes", "base": 20, "step": 15, "max": 3, "branch": "filo", "requires": [[0, 3]]},
	{"name": "Golpe de eco", "description": "Cada 10.º golpe de una cadena hace el triple de daño", "base": 120, "step": 0, "max": 1, "branch": "filo", "requires": [[6, 1], [7, 1]], "oath": true},
	{"name": "Lucero heredado", "description": "Empiezas cada viaje con un lucero más", "base": 40, "step": 40, "max": 2, "branch": "luceros", "requires": [[2, 3]]},
	{"name": "Órbita veloz", "description": "Los luceros atacan un 5% más rápido", "base": 15, "step": 10, "max": 5, "branch": "luceros", "requires": [[2, 3]]},
	{"name": "Enjambre", "description": "Un lucero más al empezar y ataques un 25% más rápidos; tus clics hacen un 10% menos", "base": 120, "step": 0, "max": 1, "branch": "luceros", "requires": [[9, 1], [10, 1]], "oath": true},
	{"name": "Piel de ceniza", "description": "−4% de daño recibido", "base": 12, "step": 8, "max": 5, "branch": "brasa", "requires": [[1, 3]]},
	{"name": "Último aliento", "description": "Una vez por viaje, un golpe mortal te deja con un 30% de vida, recarga Destello y desata la furia", "base": 150, "step": 0, "max": 1, "branch": "brasa", "requires": [[5, 1], [12, 1]], "oath": true}
]
# Eclipse levels unlock one at a time by clearing a cycle (a room-30 boss) at
# the previous level. Rules are cumulative; every level adds banked ascuas.
const ECLIPSE_MAX = 5
const ECLIPSE_BONUS = 0.2
const ECLIPSE_RULES = [
	"Sin modificadores.",
	"Los élites aparecen el doble de a menudo.",
	"Los enemigos golpean un 15% más fuerte.",
	"Destello recarga un 20% más lento.",
	"Los jefes tienen un 25% más de vida.",
	"Descansos y santuarios curan la mitad."]
# Thirty achievements in five groups; each pays a reward once claimed.
const ACHIEVEMENTS = [
	{"id": "first_kill", "group": "Combate", "name": "Primera brasa", "description": "Vence a tu primer enemigo.", "reward": {"essence": 5}},
	{"id": "kills_500", "group": "Combate", "name": "Exterminador", "description": "Vence a 500 enemigos.", "reward": {"essence": 20}},
	{"id": "kills_2000", "group": "Combate", "name": "Leyenda de ceniza", "description": "Vence a 2.000 enemigos.", "reward": {"essence": 40, "scrap": 10}},
	{"id": "interrupts", "group": "Combate", "name": "Mano rápida", "description": "Interrumpe 10 cargas con Destello.", "reward": {"essence": 15}},
	{"id": "parry", "group": "Combate", "name": "Guardia perfecta", "description": "Logra 25 paradas perfectas.", "reward": {"essence": 20}},
	{"id": "weak", "group": "Combate", "name": "Ojo certero", "description": "Acierta 50 puntos débiles.", "reward": {"essence": 20}},
	{"id": "armor", "group": "Combate", "name": "Rompecorazas", "description": "Rompe 5 corazas del Forjador.", "reward": {"essence": 15}},
	{"id": "king", "group": "Jefes", "name": "Rey depuesto", "description": "Derrota al Rey sin Brasa.", "reward": {"essence": 15}},
	{"id": "bell", "group": "Jefes", "name": "Silencio roto", "description": "Derrota a la Campanera Vacía.", "reward": {"essence": 20}},
	{"id": "forge", "group": "Jefes", "name": "Forja apagada", "description": "Derrota al Forjador Ciego.", "reward": {"essence": 25}},
	{"id": "idle_boss", "group": "Jefes", "name": "Los luceros bastan", "description": "Derrota a un jefe sin atacar con clic durante el combate.", "reward": {"essence": 20}},
	{"id": "untouched", "group": "Jefes", "name": "Intocable", "description": "Derrota a un jefe sin recibir daño en ese combate.", "reward": {"essence": 30}},
	{"id": "room_50", "group": "Viaje", "name": "Más allá", "description": "Llega a la cámara 50.", "reward": {"essence": 30}},
	{"id": "room_60", "group": "Viaje", "name": "Sin fondo", "description": "Llega a la cámara 60.", "reward": {"essence": 40}},
	{"id": "eclipse", "group": "Viaje", "name": "Más allá del eclipse", "description": "Supera la cámara 30 en Eclipse 1 o superior.", "reward": {"essence": 30}},
	{"id": "eclipse_5", "group": "Viaje", "name": "Noche perpetua", "description": "Supera la cámara 30 en Eclipse 5.", "reward": {"essence": 60, "scrap": 20}},
	{"id": "embers", "group": "Viaje", "name": "Cazador de ascuas", "description": "Atrapa 25 ascuas errantes.", "reward": {"essence": 15}},
	{"id": "rich", "group": "Viaje", "name": "Bolsa llena", "description": "Reúne 100.000 de oro en una expedición.", "reward": {"essence": 20}},
	{"id": "chests", "group": "Botín", "name": "Cazatesoros", "description": "Abre 15 cofres.", "reward": {"essence": 10, "scrap": 10}},
	{"id": "jackpot", "group": "Botín", "name": "La rueda sonríe", "description": "Consigue Oro ×3 en la Rueda del eclipse.", "reward": {"essence": 15}},
	{"id": "wheel_10", "group": "Botín", "name": "Jugador empedernido", "description": "Gira la Rueda del eclipse 10 veces.", "reward": {"essence": 15}},
	{"id": "legendary", "group": "Botín", "name": "Leyenda forjada", "description": "Encuentra una pieza legendaria.", "reward": {"scrap": 20}},
	{"id": "smith", "group": "Botín", "name": "Mano de herrero", "description": "Sube una pieza a su nivel máximo.", "reward": {"scrap": 15}},
	{"id": "synergy", "group": "Botín", "name": "Afinidad", "description": "Completa una sinergia de reliquias.", "reward": {"essence": 10}},
	{"id": "oath", "group": "Legado", "name": "Juramentado", "description": "Compra tu primer juramento.", "reward": {"essence": 15}},
	{"id": "masteries", "group": "Legado", "name": "Maestro", "description": "Sube una maestría a su nivel máximo.", "reward": {"scrap": 15}},
	{"id": "bearers", "group": "Legado", "name": "Muchas manos", "description": "Desbloquea todos los portadores.", "reward": {"essence": 40}},
	{"id": "daily", "group": "Legado", "name": "Constancia", "description": "Completa 10 retos diarios.", "reward": {"essence": 30}},
	{"id": "weekly", "group": "Legado", "name": "Semana de brasas", "description": "Completa un reto semanal.", "reward": {"essence": 25}},
	{"id": "collection", "group": "Legado", "name": "Memoria del eclipse", "description": "Completa la colección.", "reward": {"essence": 50, "scrap": 20}}]
const ACHIEVEMENT_GROUPS = ["Combate", "Jefes", "Viaje", "Botín", "Legado"]
# Retos: three daily and two weekly goals picked from the date, the same for
# everyone that day or week. Progress comes from play; rewards are claimed.
const MISSION_KINDS = {
	"kills": {"text": "Vence a %d enemigos", "daily": 60, "weekly": 400},
	"elites": {"text": "Vence a %d élites", "daily": 4, "weekly": 20},
	"bosses": {"text": "Derrota a %d jefes", "daily": 2, "weekly": 10},
	"parries": {"text": "Logra %d paradas perfectas", "daily": 8, "weekly": 40},
	"weak": {"text": "Acierta %d puntos débiles", "daily": 10, "weekly": 50},
	"chests": {"text": "Abre %d cofres", "daily": 3, "weekly": 15},
	"interrupts": {"text": "Interrumpe %d cargas con Destello", "daily": 4, "weekly": 20},
	"embers": {"text": "Atrapa %d ascuas errantes", "daily": 3, "weekly": 15},
	"room": {"text": "Llega a la cámara %d en una expedición", "daily": 20, "weekly": 40}}
const MISSION_IDS = ["kills", "elites", "bosses", "parries", "weak", "chests", "interrupts", "embers", "room"]
const DAILY_COUNT = 3
const WEEKLY_COUNT = 2
const DAILY_REWARD = {"essence": 12, "scrap": 4}
const WEEKLY_REWARD = {"essence": 50, "scrap": 15}
# Completing every entry of a collection category pays this once.
const CATEGORY_REWARD = {"essence": 25, "scrap": 8}
const HISTORY_SIZE = 8
# Mapa de caminos. After each milestone relic the map offers three lanes for
# the next four chambers; the fifth (milestone or boss) is shared. Every node
# is still a fight: the node adds what happens around it.
const LANE_LENGTH = 4
const LANES = [
	{"id": "safe", "name": "Sendero de las brasas", "hint": "Descansos, santuarios y la fragua para llegar entero.", "weights": {"fight": 4, "rest": 3, "shrine": 2, "merchant": 1, "chest": 1, "smithy": 1}, "must": ["rest"]},
	{"id": "risk", "name": "Senda del desafío", "hint": "Élites, duelos y cofres: más peligro, más botín.", "weights": {"fight": 2, "elite": 4, "chest": 3, "altar": 1, "duel": 1}, "must": ["elite", "chest"]},
	{"id": "luck", "name": "Camino del azar", "hint": "Mercaderes, altares, la fragua y la Rueda del eclipse.", "weights": {"fight": 2, "wheel": 3, "merchant": 2, "altar": 2, "chest": 1, "shrine": 1, "smithy": 1}, "must": ["wheel"]}]
const NODES = {
	"fight": {"name": "Combate", "hint": "Un rival corriente."},
	"elite": {"name": "Élite", "hint": "Rival élite: ×2,2 vida y ×1,3 daño. Paga ×2,5 oro y una ascua más."},
	"rest": {"name": "Descanso", "hint": "Recuperas vida al llegar y el rival nunca es élite."},
	"chest": {"name": "Cofre", "hint": "Un cofre antes del combate: oro, ascuas, luceros, forja o una reliquia."},
	"shrine": {"name": "Santuario de la brasa", "hint": "Cura sin coste antes del combate."},
	"merchant": {"name": "Mercader de cenizas", "hint": "Vende un lucero más barato que la forja."},
	"altar": {"name": "Altar del eclipse", "hint": "Cambia vida por daño durante la expedición."},
	"wheel": {"name": "Rueda del eclipse", "hint": "Apuesta oro y gira: premios… o nada."},
	"smithy": {"name": "Fragua errante", "hint": "Sube dos niveles de una mejora de forja por el precio de uno."},
	"duel": {"name": "Duelo", "hint": "Un élite con dos afijos. Vencerlo te da una pieza del Arsenal."}}
const EVENT_NODES = ["shrine", "merchant", "altar", "wheel", "smithy"]
# How many times one lane may hold a node; plain fights have no limit.
const NODE_MAX = {"elite": 2, "rest": 2, "chest": 2, "shrine": 1, "merchant": 1, "altar": 1, "wheel": 1, "smithy": 1, "duel": 1}
const CHEST_NAMES = ["Cofre de madera", "Cofre de hierro", "Cofre del eclipse"]
# Chest rewards: gold scales with the chamber, a relic is rarer in plain chests.
const LOOT_WEIGHTS = {"gold": 5, "essence": 3, "heal": 2, "wisp": 2, "forge": 2}
const LOOT_RELIC = [0, 1, 3]
const LOOT_GOLD = [4.0, 6.0, 9.0]
const LOOT_ESSENCE = [1, 2, 4]
# The Rueda has ten equal sectors; each one lands one time in ten.
const WHEEL = ["gold2", "nothing", "heal", "gold3", "nothing", "relic", "gold2", "chest", "nothing", "essence"]
const WHEEL_NAMES = {"gold2": "Oro ×2", "gold3": "Oro ×3", "nothing": "Nada", "heal": "Vida", "relic": "Reliquia", "chest": "Cofre", "essence": "Ascuas"}
# Arsenal: permanent equipment in three slots. Pieces come from chests,
# elites and bosses, keep their level between expeditions and are upgraded
# or salvaged with esquirlas. A piece's power is its base value times its
# rarity, plus LEVEL_STEP of that per level.
const SLOTS = ["weapon", "talisman", "amulet"]
const SLOT_NAMES = {"weapon": "Arma", "talisman": "Talismán", "amulet": "Amuleto"}
const RARITIES = ["Común", "Rara", "Épica", "Legendaria"]
const RARITY_COLORS = ["b8c0c8", "6fb4ff", "c48cf5", "ffb347"]
# Tuned with the bot over three seeds: the arsenal adds about five chambers to
# active play by the ninth to twelfth expedition.
const RARITY_POWER = [1.0, 1.35, 1.8, 2.4]
const RARITY_MAX_LEVEL = [4, 6, 8, 10]
# Icon order follows assets/art/loot/items.png.
const ITEM_IDS = ["ash_sword", "comet_blade", "rune_spear", "wisp_lantern", "black_hourglass", "silver_bell", "moss_charm", "split_coin", "forge_scale"]
const ITEMS = {
	"ash_sword": {"slot": "weapon", "name": "Espada de ceniza", "stat": "click", "base": 0.05},
	"comet_blade": {"slot": "weapon", "name": "Hoja del cometa", "stat": "crit", "base": 0.015},
	"rune_spear": {"slot": "weapon", "name": "Lanza rúnica", "stat": "burst", "base": 0.08},
	"wisp_lantern": {"slot": "talisman", "name": "Farol de luceros", "stat": "wisp", "base": 0.05},
	"black_hourglass": {"slot": "talisman", "name": "Reloj de arena negra", "stat": "cooldown", "base": 0.025},
	"silver_bell": {"slot": "talisman", "name": "Campanilla de plata", "stat": "speed", "base": 0.025},
	"moss_charm": {"slot": "amulet", "name": "Amuleto de musgo", "stat": "hp", "base": 0.04},
	"split_coin": {"slot": "amulet", "name": "Moneda partida", "stat": "gold", "base": 0.05},
	"forge_scale": {"slot": "amulet", "name": "Escama de forja", "stat": "guard", "base": 0.02}}
const STAT_TEXT = {"click": "+%s%% de daño por clic", "crit": "+%s%% de probabilidad crítica", "burst": "+%s%% de daño de Destello",
	"wisp": "+%s%% de daño de luceros", "cooldown": "−%s%% de recarga de Destello", "speed": "+%s%% de velocidad de luceros",
	"hp": "+%s%% de vida máxima", "gold": "+%s%% de oro", "guard": "−%s%% de daño recibido"}
const STAT_NAMES = {"click": "más daño por clic", "crit": "más probabilidad crítica", "burst": "más daño de Destello", "wisp": "más daño de luceros",
	"cooldown": "Destello recarga antes", "speed": "luceros más rápidos", "hp": "más vida máxima", "gold": "más oro", "guard": "menos daño recibido"}
const TRAIT_IDS = ["vampire", "keen", "steady", "thorns", "lucky", "embers"]
const TRAITS = {
	"vampire": {"name": "Sed de brasas", "text": "Tus críticos manuales curan un 1% de tu vida máxima."},
	"keen": {"name": "Ojo de halcón", "text": "Los puntos débiles aparecen el doble de a menudo."},
	"steady": {"name": "Pulso sereno", "text": "La parada perfecta dura 0,1 s más."},
	"thorns": {"name": "Espinas de obsidiana", "text": "Al bloquear devuelves el doble del daño que te llega."},
	"lucky": {"name": "Buena estrella", "text": "Un 30% de los cofres sube un nivel de calidad."},
	"embers": {"name": "Imán de ascuas", "text": "Las ascuas errantes aparecen el doble de a menudo."}}
# Each level adds this share of the piece's base power.
const LEVEL_STEP = 0.08
const SALVAGE = [2, 5, 12, 30]
const UPGRADE_STEP = [2, 3, 5, 8]
const ARMORY_SIZE = 24
# Chance of each rarity by where a piece is found.
const RARITY_WEIGHTS = {"elite": [70, 25, 5, 0], "wood": [65, 28, 7, 0], "iron": [45, 38, 14, 3], "eclipse": [20, 40, 30, 10], "boss": [40, 38, 18, 4]}
const ELITE_DROP = 0.15
# Portadores: the bearer is chosen at the bonfire. Each one changes a few
# stats and adds an effect to Destello, which keeps its boss mechanics
# (interrupts, shields, armour) for everyone. Unlocked by an achievement.
const BEARER_IDS = ["bearer", "sentinel", "summoner", "wanderer"]
const BEARERS = {
	"bearer": {"name": "El Portador", "role": "Equilibrio", "unlock": "", "hue": 0.0, "scale": 1.0,
		"passive": "Destello recarga un 15% más rápido y golpea un 15% más fuerte.",
		"technique": "Destello", "technique_text": "Golpea por ocho, interrumpe cargas y rompe escudos.",
		"burst_cd": 0.85, "burst": 1.15},
	"sentinel": {"name": "La Centinela", "role": "Guardia", "unlock": "parry", "hue": 0.55, "scale": 1.06,
		"passive": "+10% de vida y parada perfecta 0,1 s más larga. Sus clics hacen un 15% menos.",
		"technique": "Muro de brasas", "technique_text": "Destello levanta además un muro que absorbe daño (un 25% de su vida) durante 6 segundos.",
		"hp": 1.1, "perfect": 0.1, "click": 0.85},
	"summoner": {"name": "La Invocadora", "role": "Luceros", "unlock": "bell", "hue": 0.42, "scale": 1.0,
		"passive": "Empieza con un lucero más y sus luceros hacen un 30% más. Sus clics hacen un 20% menos.",
		"technique": "Llamada del enjambre", "technique_text": "Destello invoca además tres luceros durante 8 segundos.",
		"start_wisps": 1, "wisp": 1.3, "click": 0.8},
	"wanderer": {"name": "El Errante", "role": "Fortuna", "unlock": "chests", "hue": 0.8, "scale": 1.0,
		"passive": "+10% de oro y ascuas errantes más a menudo. −10% de vida.",
		"technique": "Golpe de fortuna", "technique_text": "Cada Destello deja además oro: un tercio de una victoria de la cámara.",
		"gold": 1.1, "ember": 0.6, "hp": 0.9}}
const SUMMON_TIME = 8.0
const SUMMON_COUNT = 3
# Muro de brasas absorbs this share of maximum health and fades after a while.
# A wall that stopped any one blow made charged boss attacks harmless.
const WALL_SHARE = 0.25
const WALL_TIME = 6.0
const FORTUNE = 1.0 / 3.0
# Maestrías: permanent upgrades of the three skills, bought with esquirlas.
# Each level costs `cost` times the level it reaches.
const MASTERIES = [
	{"id": "burst_power", "name": "Destello ardiente", "text": "+8% de daño de Destello por nivel", "max": 5, "cost": 9},
	{"id": "burst_haste", "name": "Recarga veloz", "text": "−4% de recarga de Destello por nivel", "max": 5, "cost": 12},
	{"id": "guard_window", "name": "Guardia amplia", "text": "+0,04 s de parada perfecta por nivel", "max": 3, "cost": 15},
	{"id": "riposte", "name": "Contraataque", "text": "+0,5× al contraataque de la parada por nivel", "max": 4, "cost": 12},
	{"id": "firm_guard", "name": "Guardia firme", "text": "El bloqueo detiene un 5% más del golpe por nivel", "max": 4, "cost": 12},
	{"id": "weak_eye", "name": "Ojo afilado", "text": "+0,25 s de punto débil y +0,2× a su golpe por nivel", "max": 4, "cost": 12}]
const OATH_ECHO = 8
const OATH_SWARM = 11
const OATH_LAST_BREATH = 13
const COMBO_BASE = 20
const BIOMES = ["JARDÍN DE LAS CENIZAS", "CRIPTAS DEL ECO", "FORJA DEL ECLIPSE"]
const BIOME_RULES = [
	"Las ruinas guardan silencio. Sin efectos de ambiente.",
	"Eco: si pasas 2 s sin atacar con clic o Espacio, los enemigos recuperan vida.",
	"Calor: +25% de oro, pero los enemigos golpean un 15% más fuerte."
]
const ENEMY_NAMES = [
	["Gelatina de hollín", "Lucero extraviado", "Centinela hueco"],
	["Gelatina del eco", "Lucero sepulcral", "Centinela de cripta"],
	["Gelatina de escoria", "Lucero de brasa", "Centinela forjado"]
]
const BOSS_TITLES = ["SEÑOR DEL JARDÍN", "SEÑOR DE LAS CRIPTAS", "SEÑOR DE LA FORJA"]
const EMBER_KINDS = ["gold", "fury", "heal", "spark"]
# Between chambers the bearer walks on and the next rival arrives on foot.
const SPAWN_DELAY = 1.1
const BOSS_INTRO = 1.6
# The first meeting with each boss earns a longer entrance: the walk-in, then
# a closer look with its name and how to face it. Skipping leaves a moment.
const BOSS_INTRO_FULL = 3.2
const INTRO_SKIP_LEFT = 0.3
const CHARGE_TIME = 3.0
const STORM_LEGACY_MAX = 10
const CLICK_INTERVAL = 0.3
const HIT_DELAY = 0.15
# Crypt echo: seconds without a manual attack before enemies heal, and the
# share of their maximum health recovered per second.
const ECHO_REST = 2.0
const ECHO_REGEN = 0.03
# Forjador Ciego: share of his maximum health covered by each molten armour,
# Destello's bonus against it and the strength of the pour when it survives.
const FORGE_ARMOR = 0.12
const FORGE_BURST = 1.5
const FORGE_POUR = 2.4
# Parada: a short guard. A normal blow that lands early in it (a perfect
# parry) is cancelled, the enemy is stunned and the bearer ripostes; later in
# the guard it is only blocked. Charged blows are never cancelled. A guard that
# catches nothing leaves a longer recovery, so mashing does not pay.
const PARRY_WINDOW = 0.5
const PARRY_PERFECT = 0.25
const PARRY_WHIFF = 1.6
const PARRY_RECOVER = 0.4
const PARRY_STUN = 0.8
const PARRY_RIPOSTE = 2.0
# Share of the blow that still lands: blocked normal blow, charged blow after a
# perfect guard, charged blow after a late one, boss blow after a perfect parry.
# Bosses are too heavy to turn aside completely, so they stay a test of
# health and damage (simulation: without this, skilled play skipped the
# room-30 wall entirely).
const PARRY_BLOCK = 0.5
const PARRY_HEAVY = 0.5
const PARRY_HEAVY_BLOCK = 0.75
const PARRY_BOSS = 0.5
# Punto débil: a spot that lights up on the enemy. Only an aimed click reaches
# it; the hit is a sure critical with a bonus and speeds up Destello.
const WEAK_FIRST = 4.0
const WEAK_TIME = 2.6
const WEAK_BONUS = 1.5
const WEAK_RECHARGE = 1.5

var rng = RandomNumberGenerator.new()
# Expedition
var room: int = 1
var gold: float = 0
var hp: float = 100
var enemy_hp: float = 24
var enemy_max: float = 24
var enemy_elite: bool = false
var shield_hits: int = 0
var affixes: Array = []
var burn_time: float = 0
var burn_dps: float = 0
var bell_resonance: int = 0
var forge_armor: float = 0
var manual_rest: float = 0
var shelter_ready: bool = false
var attack_timer: float = 0
var auto_timer: float = 0
var click_cooldown: float = 0
var pending_hit: float = 0
var pending_damage: float = 0
var pending_critical: bool = false
var pending_echo: bool = false
var parry_window: float = 0
var parry_cooldown: float = 0
var weak_active: bool = false
var weak_timer: float = 0
var weak_cooldown: float = WEAK_FIRST
# Offset of the weak point from the enemy's centre, each axis in -1..1.
var weak_pos: Vector2 = Vector2.ZERO
var last_breath_used: bool = false
var burst_cooldown: float = 0
var combo: int = 0
var combo_time: float = 0
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
var lanes: Array = []
var lane: int = -1
var lane_start: int = 0
var chest_tier: int = 0
# Forge upgrade the Fragua errante offers (an index into UPGRADES).
var smithy_kind: int = 0
# Rewards of the last chest or spin, for the screen that reveals them.
var last_loot: Array = []
var wheel_result: int = -1
var run_essence: int = 0
var run_kills: int = 0
var run_gold: float = 0
var run_time: float = 0
var run_bosses: int = 0
# Permanent
var discoveries: Array = []
var essence: int = 0
var legacy: Array = []
var oath: int = -1
var best: int = 1
var run_start_best: int = 1
var eclipse: int = 0
var eclipse_unlocked: int = 0
var achievements: Array = []
var history: Array = []
var total_interrupts: int = 0
var total_armor_breaks: int = 0
var total_parries: int = 0
var total_weak: int = 0
var total_chests: int = 0
var total_spins: int = 0
var total_items: int = 0
# Arsenal (permanent)
var armory: Array = []
var equipped: Dictionary = {"weapon": -1, "talisman": -1, "amulet": -1}
var scrap: int = 0
var masteries: Dictionary = {}
var next_item_uid: int = 1
var bearer: String = "bearer"
# Retos y recompensas (permanent)
var achievements_claimed: Array = []
var collection_claimed: Array = []
var bestiary: Dictionary = {}
var mission_day: int = -1
var mission_week: int = -1
var daily: Array = []
var weekly: Array = []
var total_missions: int = 0
var daily_done: int = 0
var total_time: float = 0
# Blows taken in the current fight, for Intocable.
var fight_hits: int = 0
# Muro de brasas and Llamada del enjambre while they last.
var wall: float = 0
var wall_time: float = 0
var summon_time: float = 0
# Pieces found during this expedition, for the summary.
var run_items: Array = []
var fight_clicks: int = 0
var last_banked: int = 0
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
# "auto" follows the system: Spanish if it is Spanish, English otherwise.
var language: String = "auto"
var save_error: String = ""
var offline_reward: float = 0

func _init() -> void:
	rng.randomize()
	legacy.resize(LEGACY.size())
	legacy.fill(0)

# ---------------------------------------------------------------- derived stats
func collection_catalog() -> Array:
	var entries: Array = []
	var enemies = [
		["slime", "Gelatina", "Una criatura de las ruinas que ataca con embestidas."],
		["wisp", "Lucero extraviado", "Un espíritu errante; cambia de aspecto entre biomas."],
		["sentinel", "Centinela hueco", "Armadura pesada y golpes lentos."],
		["guardian", "Guardián del Umbral", "Cuatro impactos rompen su escudo. Destello lo rompe de inmediato."],
		["acolyte", "Acólito del Eco", "Canaliza durante tres segundos. Destello cancela su ataque."],
		["king", "Rey sin Brasa", "Cada tercer ataque prepara su Brasa. Interrúmpelo con Destello."],
		["bell", "Campanera Vacía", "Silencio castiga los ataques manuales; Toque Fúnebre se interrumpe con Destello."],
		["forge", "Forjador Ciego", "Cada tercer ataque se cubre con una coraza fundida. Rómpela antes de que se vierta; Destello la golpea con más fuerza."]]
	for entry in enemies:
		entries.append({"id": "enemy:" + entry[0], "category": "Enemigos", "name": entry[1], "description": entry[2]})
	for relic in RELICS:
		entries.append({"id": "relic:" + relic.id, "category": "Reliquias", "name": relic.name, "description": relic.description})
	for synergy in SYNERGIES:
		entries.append({"id": "synergy:" + synergy.id, "category": "Sinergias", "name": synergy.name, "description": synergy.description})
	for id in ITEM_IDS:
		var item: Dictionary = ITEMS[id]
		entries.append({"id": "item:" + id, "category": "Arsenal", "name": item.name, "description": "%s · %s. Su fuerza depende de la rareza y el nivel." % [SLOT_NAMES[item.slot], STAT_NAMES[item.stat]]})
	return entries

func remember(id: String) -> void:
	if not discoveries.has(id):
		discoveries.append(id)
	if id.begins_with("synergy:"):
		unlock("synergy")
	if discoveries.size() >= collection_catalog().size():
		unlock("collection")

func unlock(id: String) -> void:
	if achievements.has(id):
		return
	achievements.append(id)
	achievement_unlocked.emit(id)
	event.emit("Logro · " + achievement_name(id))
	for key in BEARER_IDS:
		if BEARERS[key].unlock == id:
			bearer_unlocked.emit(key)
			event.emit("Nuevo portador · " + BEARERS[key].name + ". Elígelo en la hoguera")
	if BEARER_IDS.all(func(key): return bearer_unlocked_by(key)):
		unlock("bearers")

func achievement_name(id: String) -> String:
	for entry in ACHIEVEMENTS:
		if entry.id == id:
			return entry.name
	return id

## Achievements an older save already earned, inferred from its counters.
func unlock_earned() -> void:
	if total_kills > 0:
		unlock("first_kill")
	if total_embers >= 25:
		unlock("embers")
	if total_parries >= 25:
		unlock("parry")
	if total_weak >= 50:
		unlock("weak")
	if total_kills >= 500:
		unlock("kills_500")
	if total_kills >= 2000:
		unlock("kills_2000")
	if best >= 50:
		unlock("room_50")
	if best >= 60:
		unlock("room_60")
	if total_spins >= 10:
		unlock("wheel_10")
	if daily_done >= 10:
		unlock("daily")
	for entry in MASTERIES:
		if mastery(entry.id) >= entry.max:
			unlock("masteries")
	for k in range(LEGACY.size()):
		if is_oath(k) and legacy_level(k) > 0:
			unlock("oath")

# ---------------------------------------------------------------- rewards
func achievement_entry(id: String) -> Dictionary:
	for entry in ACHIEVEMENTS:
		if entry.id == id:
			return entry
	return {}

func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if reward.get("essence", 0) > 0:
		parts.append("+%d ascuas" % reward.essence)
	if reward.get("scrap", 0) > 0:
		parts.append("+%d esquirlas" % reward.scrap)
	return "  ·  ".join(parts)

func _pay(reward: Dictionary) -> void:
	essence += int(reward.get("essence", 0))
	scrap += int(reward.get("scrap", 0))

func claim_achievement(id: String) -> bool:
	if not achievements.has(id) or achievements_claimed.has(id):
		return false
	achievements_claimed.append(id)
	_pay(achievement_entry(id).reward)
	changed.emit()
	return true

func category_complete(category: String) -> bool:
	var entries = collection_catalog().filter(func(entry): return entry.category == category)
	return not entries.is_empty() and entries.all(func(entry): return discoveries.has(entry.id))

func claim_category(category: String) -> bool:
	if not category_complete(category) or collection_claimed.has(category):
		return false
	collection_claimed.append(category)
	_pay(CATEGORY_REWARD)
	changed.emit()
	return true

## Day and Monday-based week numbers of a calendar date, for the retos.
static func day_number(date: Dictionary) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": date.year, "month": date.month, "day": date.day, "hour": 0, "minute": 0, "second": 0}) / 86400)

static func week_number(day: int) -> int:
	return int(floor((day + 3) / 7.0))

func _pick_missions(seed_value: int, count: int, period: String) -> Array:
	var picker = RandomNumberGenerator.new()
	picker.seed = seed_value
	var pool: Array = MISSION_IDS.duplicate()
	var picked: Array = []
	for i in range(count):
		var kind: String = pool.pop_at(picker.randi_range(0, pool.size() - 1))
		picked.append({"kind": kind, "target": MISSION_KINDS[kind][period], "progress": 0, "claimed": false})
	return picked

## New retos when the day or the week changes; unclaimed ones are lost.
func refresh_missions(day: int) -> bool:
	var refreshed := false
	if day != mission_day:
		mission_day = day
		daily = _pick_missions(day * 7919 + 17, DAILY_COUNT, "daily")
		refreshed = true
	var week = week_number(day)
	if week != mission_week:
		mission_week = week
		weekly = _pick_missions(week * 104729 + 3, WEEKLY_COUNT, "weekly")
		refreshed = true
	if refreshed:
		changed.emit()
	return refreshed

func mission_text(mission: Dictionary) -> String:
	return MISSION_KINDS[mission.kind].text % mission.target

func mission_done(mission: Dictionary) -> bool:
	return mission.progress >= mission.target

## Counts play toward the retos; "room" keeps the deepest chamber instead.
func progress_mission(kind: String, amount: int = 1) -> void:
	for mission in daily + weekly:
		if mission.kind != kind or mission.claimed or mission_done(mission):
			continue
		mission.progress = mini(mission.target, maxi(mission.progress, amount) if kind == "room" else mission.progress + amount)
		if mission_done(mission):
			mission_completed.emit(mission_text(mission))
			event.emit("Reto completado · " + mission_text(mission))

func claim_mission(is_weekly: bool, index: int) -> bool:
	var list: Array = weekly if is_weekly else daily
	if index < 0 or index >= list.size() or list[index].claimed or not mission_done(list[index]):
		return false
	list[index].claimed = true
	total_missions += 1
	_pay(WEEKLY_REWARD if is_weekly else DAILY_REWARD)
	if is_weekly:
		unlock("weekly")
	else:
		daily_done += 1
		if daily_done >= 10:
			unlock("daily")
	changed.emit()
	return true

## Rewards waiting to be claimed: retos, achievements and full categories.
func claimable_count() -> int:
	var count := 0
	for mission in daily + weekly:
		if mission_done(mission) and not mission.claimed:
			count += 1
	for id in achievements:
		if not achievements_claimed.has(id):
			count += 1
	var categories := {}
	for entry in collection_catalog():
		categories[entry.category] = true
	for category in categories:
		if category_complete(category) and not collection_claimed.has(category):
			count += 1
	return count

func eclipse_bonus() -> float:
	return 1.0 + ECLIPSE_BONUS * eclipse

## Ascuas the expedition would bank now, with the Eclipse bonus.
func banked_preview() -> int:
	return run_essence + int(floor(run_essence * ECLIPSE_BONUS * eclipse))

## The Eclipse level is chosen at the bonfire, between expeditions.
func set_eclipse(level: int) -> bool:
	if not dead or level < 0 or level > eclipse_unlocked:
		return false
	eclipse = level
	changed.emit()
	return true

func rest_heal() -> float:
	return 0.1 if eclipse >= 5 else 0.2

func shrine_heal() -> float:
	return 0.225 if eclipse >= 5 else 0.45

func remember_relics() -> void:
	for relic in relics:
		remember("relic:" + relic)
	for synergy in SYNERGIES:
		if has_synergy(synergy.id):
			remember("synergy:" + synergy.id)

## Collection id of the current enemy: each boss and role has its own entry.
func enemy_id() -> String:
	if is_boss():
		return "bell" if is_bell_keeper() else ("forge" if is_forge_keeper() else "king")
	return enemy_role() if not enemy_role().is_empty() else enemy_kind()

func remember_enemy() -> void:
	if dead:
		return
	remember("enemy:" + enemy_id())

## How to face each boss, shown on the first meeting.
func boss_lore() -> String:
	match enemy_id():
		"bell": return "«Cuando la campana calle, calla tu espada. Cuando doble, Destello.»"
		"forge": return "«Su coraza fundida dura tres segundos. Rómpela antes de que se vierta.»"
	return "«Cada tercer golpe prepara su Brasa. Guarda el Destello para ese momento.»"

func in_boss_intro() -> bool:
	return is_boss() and spawn_delay > 0 and active()

func skip_intro() -> bool:
	if not in_boss_intro() or spawn_delay <= INTRO_SKIP_LEFT:
		return false
	spawn_delay = INTRO_SKIP_LEFT
	changed.emit()
	return true

func count_relic(id: String) -> int:
	return relics.count(id)

func has_synergy(id: String) -> bool:
	for synergy in SYNERGIES:
		if synergy.id == id:
			return relics.has(synergy.pair[0]) and relics.has(synergy.pair[1])
	return false

func synergy_hint(relic_id: String) -> String:
	var hints: Array[String] = []
	for synergy in SYNERGIES:
		if relic_id not in synergy.pair:
			continue
		var other: String = synergy.pair[1] if synergy.pair[0] == relic_id else synergy.pair[0]
		var other_name: String = RELICS[RELIC_IDS.find(other)].name
		hints.append(("ACTIVA " if relics.has(other) else "Con " + other_name + ": ") + synergy.name + " · " + synergy.description)
	return "\n".join(hints)

func legacy_level(kind: int) -> int:
	return int(legacy[kind]) if kind < legacy.size() else 0

func max_hp() -> float:
	return (120.0 + legacy_level(1) * 20 + count_relic("heart") * 35 + armor * 15) * (1.0 + gear("hp")) * bearer_stat("hp", 1.0)

func power_multiplier() -> float:
	return (1.0 + legacy_level(0) * 0.08) * (1.0 + altar_pacts * 0.2)

func click_damage() -> float:
	var base = (5.0 + blade * 3.5 + legacy_level(0) * 2) * (1.0 + count_relic("fang") * 0.3) * power_multiplier()
	return base * (2.0 if fury_time > 0 else 1.0) * (0.9 if oath == OATH_SWARM else 1.0) * (1.0 + gear("click")) * bearer_stat("click", 1.0)

func wisp_damage() -> float:
	return (4.0 + legacy_level(2) * 1.0) * (1.0 + count_relic("clock") * 0.4) * power_multiplier() * (1.0 + gear("wisp")) * bearer_stat("wisp", 1.0)

func auto_damage() -> float:
	return (wisps + summoned()) * wisp_damage() * (1.3 if has_synergy("chorus") and manual_rest >= 2.0 else 1.0)

## Seconds between companion volleys: Órbita veloz and the Enjambre oath.
func wisp_interval() -> float:
	return (1.0 - mini(legacy_level(10), LEGACY[10].max) * 0.05) * (0.75 if oath == OATH_SWARM else 1.0) / (1.0 + gear("speed"))

func max_combo() -> int:
	return COMBO_BASE + mini(legacy_level(7), LEGACY[7].max) * 5

func critical_chance() -> float:
	return minf(0.65, 0.08 + count_relic("eye") * 0.12 + focus * 0.03 + mini(legacy_level(6), LEGACY[6].max) * 0.02 + gear("crit"))

func critical_multiplier() -> float:
	return 2.0 + focus * 0.1

func gold_multiplier() -> float:
	return (1.0 + 0.35 * count_relic("coin")) * (1.0 + legacy_level(3) * 0.1) * (1.25 if biome() == 2 else 1.0) * (1.0 + gear("gold")) * bearer_stat("gold", 1.0)

func burst_damage() -> float:
	return (click_damage() * 8 + auto_damage() * 3) * (1.0 + count_relic("storm") * 0.25) * (1.0 + gear("burst")) * (1.0 + 0.08 * mastery("burst_power")) * bearer_stat("burst", 1.0)

func burst_max_cooldown() -> float:
	return 12.0 * pow(0.8, count_relic("storm")) * pow(0.94, mini(legacy_level(5), STORM_LEGACY_MAX)) * (1.2 if eclipse >= 3 else 1.0) * (1.0 - gear("cooldown")) * (1.0 - 0.04 * mastery("burst_haste")) * bearer_stat("burst_cd", 1.0)

func legacy_maxed(kind: int) -> bool:
	return legacy_level(kind) >= LEGACY[kind].max

func legacy_unlocked(kind: int) -> bool:
	for requirement in LEGACY[kind].requires:
		if legacy_level(requirement[0]) < requirement[1]:
			return false
	return true

func is_oath(kind: int) -> bool:
	return kind >= 0 and kind < LEGACY.size() and LEGACY[kind].get("oath", false)

func can_buy_legacy(kind: int) -> bool:
	return kind >= 0 and kind < LEGACY.size() and dead and not legacy_maxed(kind) and legacy_unlocked(kind) and essence >= legacy_price(kind)

## Oaths are chosen at the bonfire, between expeditions; only one is active.
func set_oath(kind: int) -> bool:
	if not dead or (kind != -1 and (not is_oath(kind) or legacy_level(kind) <= 0)):
		return false
	oath = kind
	changed.emit()
	return true

func is_boss() -> bool:
	return room % 10 == 0

func biome() -> int:
	return int((room - 1) / 10.0) % 3

func cycle() -> int:
	return int((room - 1) / 30.0)

func is_bell_keeper() -> bool:
	return is_boss() and biome() == 1

func is_forge_keeper() -> bool:
	return is_boss() and biome() == 2

func forge_armor_max() -> float:
	return enemy_max * FORGE_ARMOR

func bell_silence() -> bool:
	return is_bell_keeper() and boss_attacks % 4 == 1

func enemy_role() -> String:
	if not is_boss():
		if room % 10 == 6:
			return "guardian"
		if room % 10 == 8:
			return "acolyte"
	return ""

func enemy_index() -> int:
	return 2 if enemy_role() == "guardian" else (1 if enemy_role() == "acolyte" else (room - 1) % 3)

func enemy_kind() -> String:
	return "boss" if is_boss() else ["slime", "wisp", "sentinel"][enemy_index()]

func charge_name() -> String:
	if is_bell_keeper():
		return "SILENCIO" if bell_silence() else "TOQUE FÚNEBRE"
	if is_forge_keeper():
		return "CORAZA FUNDIDA"
	return "ECO ABISAL" if enemy_role() == "acolyte" else "BRASA DEL REY"

func charge_hint() -> String:
	if bell_silence():
		return "Suelta clic / Espacio · luceros seguros"
	if is_forge_keeper():
		return "Rómpela antes de que se vierta · Destello ×1,5"
	return "Interrumpe con Destello [E]"

func enemy_hint() -> String:
	if is_bell_keeper():
		return "Silencio: suelta el ataque · Toque: Destello"
	if is_forge_keeper():
		return "Coraza fundida: rómpela a golpes · Destello ×1,5"
	if shield_hits > 0:
		return "Escudo: %d golpes · Destello lo rompe" % shield_hits
	if enemy_role() == "guardian":
		return "Escudo roto · daño completo"
	if enemy_role() == "acolyte":
		return "Canaliza Eco · interrumpe con Destello"
	if enemy_elite and not affixes.is_empty():
		return "  ·  ".join(affixes.map(func(id): return AFFIXES[id].hint))
	return ""

func break_shield() -> void:
	if shield_hits <= 0:
		return
	shield_hits = 0
	shield_broken.emit()
	event.emit("¡Escudo roto! El Guardián recibe daño completo.")

func enemy_name() -> String:
	if is_boss():
		if is_forge_keeper():
			return "FORJADOR CIEGO"
		return "CAMPANERA VACÍA" if is_bell_keeper() else "EL REY SIN BRASA"
	var title = "Guardián del Umbral" if enemy_role() == "guardian" else ("Acólito del Eco" if enemy_role() == "acolyte" else ENEMY_NAMES[biome()][enemy_index()])
	if not enemy_elite:
		return title
	var words: Array = affixes.map(func(id): return AFFIXES[id].name)
	return ("Élite " + " y ".join(words) if not words.is_empty() else "Élite") + " · " + title

## The rival's own name, without the élite label.
func enemy_title() -> String:
	if is_boss():
		return enemy_name()
	return "Guardián del Umbral" if enemy_role() == "guardian" else ("Acólito del Eco" if enemy_role() == "acolyte" else ENEMY_NAMES[biome()][enemy_index()])

## "ÉLITE ARDIENTE Y VELOZ", for the plate over an élite.
func affix_label() -> String:
	var words: Array = affixes.map(func(id): return AFFIXES[id].name)
	return ("ÉLITE " + " Y ".join(words) if not words.is_empty() else "ÉLITE").to_upper()

func has_affix(id: String) -> bool:
	return enemy_elite and affixes.has(id)

func _roll_affixes(count: int) -> Array:
	var pool: Array = AFFIX_IDS.duplicate()
	var picked: Array = []
	for i in range(count):
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked

func boss_title() -> String:
	return "GUARDIANA DEL ECO" if is_bell_keeper() else BOSS_TITLES[biome()]

func attack_interval() -> float:
	if is_boss():
		return 4.0
	return [5.6, 4.8, 6.6][enemy_index()] * (0.65 if has_affix("swift") else 1.0)

func enemy_damage() -> float:
	var raw = (5 + room * 1.35) * (1.7 if is_boss() else 1.0) * (1.3 if enemy_elite else 1.0) * (1.15 if biome() == 2 else 1.0) * (1.15 if eclipse >= 2 else 1.0)
	raw *= [1.0, 0.85, 1.25][enemy_index()] if not is_boss() else 1.0
	return maxf(1, raw - armor * 2)

func heavy_damage() -> float:
	if is_bell_keeper():
		return enemy_damage() * (0.7 + bell_resonance * 0.25 if bell_silence() else 2.4)
	if is_forge_keeper():
		return enemy_damage() * FORGE_POUR
	return enemy_damage() * (1.6 if enemy_role() == "acolyte" else 3.0)

## Gold of an ordinary victory in this chamber, for prices and prizes that
## must not depend on whether the current rival is an elite or a boss.
func room_reward() -> float:
	return (16 + room * 6.5) * gold_multiplier()

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

## Crypt echo heals the enemy while the bearer rests the blade. Companion hits
## and Destello do not stop it, so the rule works from the first lucero on.
## The Campanera's Silence asks the player to rest, so it never heals her.
func echo_healing() -> bool:
	return biome() == 1 and manual_rest >= ECHO_REST and enemy_hp < enemy_max and not (charging and bell_silence())

func next_is_heavy() -> bool:
	if is_bell_keeper():
		return boss_attacks % 2 == 1
	return enemy_role() == "acolyte" or (is_boss() and boss_attacks % 3 == 2)

# ---------------------------------------------------------------- simulation
func tick(delta: float) -> void:
	if not active():
		return
	run_time += delta
	total_time += delta
	manual_rest = minf(2, manual_rest + delta)
	click_cooldown = maxf(0, click_cooldown - delta)
	burst_cooldown = maxf(0, burst_cooldown - delta)
	parry_window = maxf(0, parry_window - delta)
	parry_cooldown = maxf(0, parry_cooldown - delta)
	summon_time = maxf(0, summon_time - delta)
	wall_time = maxf(0, wall_time - delta)
	if wall_time <= 0:
		wall = 0
	fury_time = maxf(0, fury_time - delta)
	combo_time = maxf(0, combo_time - delta)
	if combo_time <= 0:
		combo = 0
	_tick_ember(delta)
	if spawn_delay > 0:
		spawn_delay = maxf(0, spawn_delay - delta)
		changed.emit()
		return
	if pending_damage > 0:
		pending_hit = maxf(0, pending_hit - delta)
		if pending_hit <= 0:
			var damage = pending_damage
			pending_damage = 0
			if pending_echo:
				pending_echo = false
				echo_strike.emit()
			if pending_critical and has_synergy("precision"):
				burst_cooldown = maxf(0, burst_cooldown - 0.4)
			if pending_critical and has_trait("vampire"):
				hp = minf(max_hp(), hp + max_hp() * 0.01)
			var thorny = has_affix("thorny")
			damage_enemy(damage, pending_critical, false)
			if thorny:
				var thorns = enemy_damage() * 0.08
				thorned.emit(thorns)
				_lose_health(thorns)
			if not active() or spawn_delay > 0:
				return
	_tick_weak(delta)
	if count_relic("tear") > 0:
		hp = minf(max_hp(), hp + max_hp() * 0.005 * count_relic("tear") * delta)
	_tick_burn(delta)
	if not active():
		return
	if echo_healing():
		enemy_hp = minf(enemy_max, enemy_hp + enemy_max * ECHO_REGEN * delta)
	auto_timer += delta
	if auto_timer >= wisp_interval():
		auto_timer = fmod(auto_timer, wisp_interval())
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
			var damage = heavy_damage()
			var spell = charge_name()
			charging = false
			boss_attacks += 1
			bell_resonance = 0
			forge_armor = 0
			if parry_window > 0:
				var share = PARRY_HEAVY if perfect_guard() else PARRY_HEAVY_BLOCK
				damage *= share
				parry_window = 0
				parry_cooldown = PARRY_RECOVER
				parried.emit(false)
				event.emit("Parada parcial · el golpe cargado pierde un %d%%" % roundi((1.0 - share) * 100))
			_hit_hero(damage, true, spell)
	else:
		attack_timer += delta
		if attack_timer >= attack_interval():
			attack_timer = 0
			if next_is_heavy():
				charging = true
				bell_resonance = 0
				charge_timer = CHARGE_TIME
				if is_forge_keeper():
					forge_armor = forge_armor_max()
				event.emit(charge_name() + " · " + charge_hint())
				boss_charge_started.emit()
			elif parry_window > 0:
				_guard_blow()
			else:
				boss_attacks += 1
				_hit_hero(enemy_damage(), false)
	changed.emit()

func can_parry() -> bool:
	return can_strike() and parry_cooldown <= 0

## Raises the guard. The blow decides the outcome when it lands.
func parry() -> bool:
	if not can_parry():
		return false
	parry_window = PARRY_WINDOW
	parry_cooldown = PARRY_WHIFF
	parry_started.emit()
	return true

## A blow landing now would meet a perfect parry: the guard went up just in time.
func perfect_guard() -> bool:
	return parry_window > 0 and parry_window >= PARRY_WINDOW - perfect_window()

## Length of the perfect part of the guard: Guardia amplia and Pulso sereno add to it.
func perfect_window() -> float:
	return minf(PARRY_WINDOW, PARRY_PERFECT + 0.04 * mastery("guard_window") + (0.1 if has_trait("steady") else 0.0) + bearer_stat("perfect", 0.0))

func block_share() -> float:
	return maxf(0.1, PARRY_BLOCK - 0.05 * mastery("firm_guard") - 0.15 * count_relic("frost"))

func riposte_power() -> float:
	return PARRY_RIPOSTE + 0.5 * mastery("riposte")

func weak_duration() -> float:
	return WEAK_TIME + 0.25 * mastery("weak_eye") + 1.0 * count_relic("lens")

func weak_bonus() -> float:
	return WEAK_BONUS + 0.2 * mastery("weak_eye")

## Seconds before the next weak point: Ojo de halcón halves the wait.
func _weak_wait() -> float:
	return rng.randf_range(6, 10) * (0.5 if has_trait("keen") else 1.0) / (1.0 + 0.4 * count_relic("lens"))

## Seconds until the next normal blow lands, or -1 when none is coming.
func blow_in() -> float:
	if not can_strike() or charging or stun_time > 0 or next_is_heavy():
		return -1.0
	return maxf(0, attack_interval() - attack_timer)

func _guard_blow() -> void:
	var perfect = perfect_guard()
	boss_attacks += 1
	parry_window = 0
	parry_cooldown = PARRY_RECOVER
	if not perfect:
		var through = enemy_damage() * block_share()
		parried.emit(false)
		event.emit("Bloqueo · el golpe pierde un %d%%" % roundi((1.0 - block_share()) * 100))
		_hit_hero(through, false)
		if has_trait("thorns") and active():
			damage_enemy(through * 2.0, false, true)
		return
	stun_time = PARRY_STUN + 0.6 * count_relic("frost")
	if has_synergy("frostfire"):
		hp = minf(max_hp(), hp + max_hp() * 0.05)
	total_parries += 1
	progress_mission("parries")
	if total_parries >= 25:
		unlock("parry")
	parried.emit(true)
	event.emit("¡Parada perfecta! " + enemy_name() + " queda aturdido")
	if is_boss() and PARRY_BOSS > 0:
		_hit_hero(enemy_damage() * PARRY_BOSS, false)
	damage_enemy(click_damage() * riposte_power(), false, false)

func _tick_weak(delta: float) -> void:
	if weak_active:
		weak_timer = maxf(0, weak_timer - delta)
		if weak_timer <= 0:
			weak_active = false
			weak_cooldown = _weak_wait()
		return
	weak_cooldown = maxf(0, weak_cooldown - delta)
	if weak_cooldown <= 0:
		weak_active = true
		weak_timer = weak_duration()
		weak_pos = Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.5))
		weak_appeared.emit()

## An aimed click on the lit weak point.
func strike_weak() -> bool:
	return weak_active and click(true)

func _hit_hero(amount: float, heavy: bool, spell: String = "") -> void:
	if wall > 0:
		var absorbed = minf(amount, wall)
		wall -= absorbed
		amount -= absorbed
		walled.emit()
		if wall <= 0:
			wall_time = 0
		if amount <= 0:
			event.emit("Muro de brasas · el golpe no te alcanza")
			return
	if shelter_ready and has_synergy("shelter"):
		amount *= 0.6
		shelter_ready = false
		event.emit("Refugio de musgo · protege del 40% del golpe")
	amount *= 1.0 - mini(legacy_level(12), LEGACY[12].max) * 0.04
	amount *= 1.0 - gear("guard")
	if amount > 0:
		fight_hits += 1
		if has_affix("burning"):
			burn_time = BURN_TIME
			burn_dps = amount * 0.2
		if has_affix("vampiric"):
			enemy_hp = minf(enemy_max, enemy_hp + enemy_max * 0.1)
	hp = maxf(0, hp - amount)
	hero_hit.emit(amount, heavy)
	event.emit(((spell if not spell.is_empty() else charge_name()).capitalize() if heavy else "El enemigo golpea") + " · −%d de vida" % int(amount))
	_check_death()

## Burns and thorns hurt outside of blows; both can end the expedition.
func _lose_health(amount: float) -> void:
	hp = maxf(0, hp - amount)
	_check_death()

func _check_death() -> void:
	if hp <= 0 and oath == OATH_LAST_BREATH and not last_breath_used:
		hp = max_hp() * 0.3
		last_breath_used = true
		burst_cooldown = 0
		fury_time = 12.0
		last_breath.emit()
		event.emit("Último aliento · la brasa se niega a apagarse. Destello listo y furia")
	if hp <= 0:
		finish_run()

func _tick_burn(delta: float) -> void:
	if burn_time <= 0:
		return
	var step = minf(delta, burn_time)
	burn_time = maxf(0, burn_time - delta)
	_lose_health(burn_dps * step)

func _tick_ember(delta: float) -> void:
	if ember_active:
		ember_timer = maxf(0, ember_timer - delta)
		if ember_timer <= 0:
			ember_active = false
			ember_cooldown = rng.randf_range(35, 70) * (0.5 if has_trait("embers") else 1.0) * bearer_stat("ember", 1.0)
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
	ember_cooldown = rng.randf_range(35, 70) * (0.5 if has_trait("embers") else 1.0) * bearer_stat("ember", 1.0)
	total_embers += 1
	progress_mission("embers")
	if total_embers >= 25:
		unlock("embers")
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

func click(weak: bool = false) -> bool:
	if not can_strike() or click_cooldown > 0 or (weak and not weak_active):
		return false
	click_cooldown = CLICK_INTERVAL
	manual_rest = 0
	fight_clicks += 1
	combo = mini(max_combo(), combo + 1)
	combo_time = 1.5
	if charging and bell_silence():
		bell_resonance = mini(3, bell_resonance + 1)
	pending_critical = weak or rng.randf() < critical_chance()
	pending_damage = click_damage() * (1 + combo * 0.015) * (critical_multiplier() if pending_critical else 1.0) * (weak_bonus() if weak else 1.0)
	if weak:
		weak_active = false
		weak_cooldown = _weak_wait()
		burst_cooldown = maxf(0, burst_cooldown - WEAK_RECHARGE)
		total_weak += 1
		progress_mission("weak")
		if has_synergy("hunter") and (enemy_elite or is_boss()):
			burst_cooldown = maxf(0, burst_cooldown - 3.0)
		if total_weak >= 50:
			unlock("weak")
		weak_struck.emit()
	pending_echo = oath == OATH_ECHO and combo % 10 == 0
	if pending_echo:
		pending_damage *= 3
	pending_hit = HIT_DELAY
	attack_started.emit()
	return true

func burst() -> bool:
	if not can_strike() or burst_cooldown > 0:
		return false
	burst_cooldown = burst_max_cooldown()
	var damage = burst_damage()
	# The Forjador's armour is broken by damage, not cancelled by Destello.
	var interrupted = charging and not is_forge_keeper()
	if interrupted:
		charging = false
		bell_resonance = 0
		boss_attacks += 1
		stun_time = 2.0
		attack_timer = 0
		damage *= 1.5
		if has_synergy("stormcall"):
			burst_cooldown *= 0.75
		event.emit("¡INTERRUMPIDO! " + enemy_name() + " queda aturdido")
		boss_interrupted.emit()
		total_interrupts += 1
		progress_mission("interrupts")
		if total_interrupts >= 10:
			unlock("interrupts")
	else:
		if forge_armor > 0:
			damage *= FORGE_BURST
		event.emit("DESTELLO · la llama despierta")
	break_shield()
	_technique()
	burst_released.emit(interrupted)
	var armored = forge_armor > 0
	damage_enemy(damage, true, false)
	if armored and forge_armor <= 0 and has_synergy("stormcall"):
		burst_cooldown *= 0.75
	return true

## What the chosen bearer adds to Destello.
func _technique() -> void:
	match bearer:
		"sentinel":
			wall = max_hp() * WALL_SHARE
			wall_time = WALL_TIME
		"summoner":
			summon_time = SUMMON_TIME
			event.emit("Llamada del enjambre · tres luceros acuden")
		"wanderer":
			var amount = floor(room_reward() * FORTUNE)
			_gain_gold(amount)
			fortune.emit(amount)

func summoned() -> int:
	return SUMMON_COUNT if summon_time > 0 else 0

func bearer_stat(key: String, fallback: float) -> float:
	return float(BEARERS[bearer].get(key, fallback))

func bearer_unlocked_by(id: String) -> bool:
	var achievement: String = BEARERS[id].unlock
	return achievement.is_empty() or achievements.has(achievement)

## The bearer is chosen between expeditions, like the oath.
func set_bearer(id: String) -> bool:
	if not dead or not BEARERS.has(id) or not bearer_unlocked_by(id):
		return false
	bearer = id
	changed.emit()
	return true

func break_forge_armor() -> void:
	forge_armor = 0
	total_armor_breaks += 1
	if total_armor_breaks >= 5:
		unlock("armor")
	charging = false
	charge_timer = 0
	boss_attacks += 1
	stun_time = 2.0
	attack_timer = 0
	armor_broken.emit()
	event.emit("¡Coraza rota! " + enemy_name() + " queda aturdido")

func damage_enemy(amount: float, critical: bool = false, automatic: bool = false) -> void:
	if not active():
		return
	if enemy_elite or is_boss():
		amount *= 1.0 + 0.3 * count_relic("horn")
	if has_affix("armored") and enemy_hp > enemy_max * 0.5:
		amount *= 0.6
	if shield_hits > 0:
		if shield_hits == 1:
			break_shield()
		else:
			shield_hits -= 1
			amount *= 0.65
	var dealt = amount
	if forge_armor > 0:
		var absorbed = minf(amount, forge_armor)
		forge_armor -= absorbed
		amount -= absorbed
		if forge_armor <= 0:
			break_forge_armor()
	enemy_hp = maxf(0, enemy_hp - amount)
	struck.emit(dealt, critical, automatic)
	if enemy_hp <= 0:
		defeat_enemy()
	changed.emit()

func _gain_gold(amount: float) -> void:
	gold += amount
	run_gold += amount
	total_gold += amount
	if run_gold >= 100000:
		unlock("rich")

func defeat_enemy() -> void:
	var boss = is_boss()
	if node_at(room) == "duel":
		event.emit("Duelo ganado · el rival deja una pieza del Arsenal")
		grant_item(make_item("boss"))
	if has_synergy("shelter"):
		shelter_ready = true
	var reward = kill_reward()
	_gain_gold(reward)
	var depth = int(room / 10.0)
	run_essence += (5 + depth * 2 if boss else 1 + int(room / 15.0)) + (1 if enemy_elite else 0)
	total_kills += 1
	run_kills += 1
	unlock("first_kill")
	if total_kills >= 500:
		unlock("kills_500")
	if total_kills >= 2000:
		unlock("kills_2000")
	bestiary[enemy_id()] = int(bestiary.get(enemy_id(), 0)) + 1
	progress_mission("kills")
	if enemy_elite:
		progress_mission("elites")
	if boss:
		grant_item(make_item("boss"))
		scrap += 1 + cycle()
	elif enemy_elite and rng.randf() < ELITE_DROP:
		grant_item(make_item("elite"))
	if boss:
		total_bosses += 1
		run_bosses += 1
		unlock(enemy_id())
		progress_mission("bosses")
		if fight_clicks == 0:
			unlock("idle_boss")
		if fight_hits == 0:
			unlock("untouched")
		# Clearing a cycle at the highest unlocked Eclipse opens the next one.
		if room % 30 == 0:
			if eclipse >= 1:
				unlock("eclipse")
			if eclipse >= 5:
				unlock("eclipse_5")
			if eclipse >= eclipse_unlocked and eclipse_unlocked < ECLIPSE_MAX:
				eclipse_unlocked = eclipse + 1
				event.emit("Eclipse %d desbloqueado · elígelo en la hoguera" % eclipse_unlocked)
	if enemy_elite:
		total_elites += 1
	hp = minf(max_hp(), hp + 4 + count_relic("ash") * 4 + (25 if boss else 0))
	enemy_defeated.emit(enemy_kind(), enemy_elite, boss)
	event.emit("%s vencido · +%d oro" % [enemy_name().capitalize() if boss else enemy_name(), int(reward)])
	var grant_relic = room % 5 == 0
	room += 1
	best = maxi(best, room)
	progress_mission("room", room)
	if best >= 50:
		unlock("room_50")
	if best >= 60:
		unlock("room_60")
	spawn_enemy()
	if grant_relic:
		journey_phase = "map"
		encounter_kind = ""
		make_lanes(room)
		_offer_relics()
	else:
		_enter_node()

func _offer_relics() -> void:
	var pool: Array = range(RELICS.size())
	offers.clear()
	for i in range(3):
		var pick = rng.randi_range(0, pool.size() - 1)
		offers.append(pool.pop_at(pick))
	relic_offered.emit()

func spawn_enemy(roll_elite: bool = true) -> void:
	fight_clicks = 0
	fight_hits = 0
	burn_time = 0
	burn_dps = 0
	parry_window = 0
	weak_active = false
	weak_timer = 0
	weak_cooldown = WEAK_FIRST
	bell_resonance = 0
	forge_armor = 0
	shield_hits = 4 if enemy_role() == "guardian" else 0
	pending_hit = 0
	pending_damage = 0
	if roll_elite:
		match node_at(room):
			"elite", "duel": enemy_elite = not is_boss()
			"rest": enemy_elite = false
			_: enemy_elite = not is_boss() and room >= 6 and rng.randf() < (0.24 if eclipse >= 1 else 0.12)
	affixes = _roll_affixes(2 if node_at(room) == "duel" else 1) if enemy_elite else []
	enemy_max = (45 + room * 13) * pow(1.1, mini(room - 1, 500)) * (3.5 if is_boss() else 1.0) * (2.2 if enemy_elite else 1.0) * (1.25 if is_boss() and eclipse >= 4 else 1.0)
	enemy_max *= [1.0, 0.85, 1.3][enemy_index()] if not is_boss() else 1.0
	enemy_hp = enemy_max
	attack_timer = 0
	charging = false
	charge_timer = 0
	stun_time = 0
	boss_attacks = 0
	spawn_delay = SPAWN_DELAY
	if is_boss():
		spawn_delay = BOSS_INTRO if discoveries.has("enemy:" + enemy_id()) else BOSS_INTRO_FULL
	remember_enemy()
	enemy_changed.emit()

func choose_relic(index: int) -> bool:
	if not offers.has(index):
		return false
	var relic: Dictionary = RELICS[index]
	relics.append(relic.id)
	remember_relics()
	if relic.id == "heart":
		hp = minf(max_hp(), hp + 35)
	offers.clear()
	event.emit("Reliquia obtenida · " + str(relic.name))
	changed.emit()
	return true

func _weighted(weights: Dictionary) -> String:
	var total := 0
	for key in weights:
		total += weights[key]
	var roll = rng.randi_range(1, total)
	for key in weights:
		roll -= weights[key]
		if roll <= 0:
			return key
	return weights.keys()[0]

## Three lanes for the chambers from `first`; the choice waits on the map.
func make_lanes(first: int) -> void:
	lane_start = first
	lane = -1
	lanes = []
	for spec in LANES:
		var nodes: Array = []
		var weights: Dictionary = spec.weights.duplicate()
		for k in range(LANE_LENGTH):
			var node = _weighted(weights)
			nodes.append(node)
			if nodes.count(node) >= NODE_MAX.get(node, LANE_LENGTH):
				weights.erase(node)
		# Each lane keeps its character: what it must hold goes to random spots.
		var spots: Array = range(LANE_LENGTH)
		for i in range(spots.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var swap = spots[i]
			spots[i] = spots[j]
			spots[j] = swap
		for i in range(spec.must.size()):
			if not nodes.has(spec.must[i]):
				nodes[spots[i]] = spec.must[i]
		lanes.append(nodes)

## What the chosen lane holds in chamber `at`, or "" outside it.
func node_at(at: int) -> String:
	if lane < 0 or lane >= lanes.size() or at < lane_start or at >= lane_start + LANE_LENGTH:
		return ""
	return lanes[lane][at - lane_start]

## Lanes are chosen only after the relic. Both decisions suspend combat.
func choose_lane(index: int) -> bool:
	if journey_phase != "map" or not offers.is_empty() or dead or paused or index < 0 or index >= lanes.size():
		return false
	lane = index
	journey_phase = ""
	event.emit("Camino elegido · " + LANES[index].name)
	spawn_enemy()
	_enter_node()
	changed.emit()
	return true

## Arriving at a chamber of the lane: rest heals at once; chests and events
## wait for the player before the fight.
func _enter_node() -> void:
	var node = node_at(room)
	match node:
		"rest":
			var amount = minf(max_hp() - hp, max_hp() * rest_heal())
			hp += amount
			event.emit("Descanso · recuperas %d de vida" % int(amount))
		"chest":
			journey_phase = "chest"
			var roll = rng.randf()
			chest_tier = 2 if roll < 0.1 else (1 if roll < (0.4 if room < 20 else 0.55) else 0)
			if has_trait("lucky") and rng.randf() < 0.3:
				chest_tier = mini(2, chest_tier + 1)
			if has_synergy("deep_pockets"):
				chest_tier = maxi(1, chest_tier)
			event.emit(CHEST_NAMES[chest_tier] + " · ábrelo antes del combate")
		"shrine", "merchant", "altar", "wheel", "smithy":
			journey_phase = "event"
			encounter_kind = node
			if node == "smithy":
				smithy_kind = rng.randi_range(0, UPGRADES.size() - 1)
	if not node.is_empty():
		node_entered.emit(node)

func encounter_name() -> String:
	return NODES[encounter_kind].name if NODES.has(encounter_kind) else "Encuentro"

func encounter_cost() -> int:
	match encounter_kind:
		"merchant": return maxi(1, int(price(1) * 0.8))
		"wheel": return maxi(1, int(room_reward() * 2.5))
		"smithy": return price(smithy_kind)
	return int(ceil(max_hp() * 0.25))

# ---------------------------------------------------------------- chests and the wheel
func roll_loot(tier: int) -> Array:
	var loot: Array = []
	var weights: Dictionary = LOOT_WEIGHTS.duplicate()
	weights["item"] = [1, 2, 3][tier]
	weights["scrap"] = 2
	if LOOT_RELIC[tier] > 0:
		weights["relic"] = LOOT_RELIC[tier]
	if hp >= max_hp() * 0.9:
		weights.erase("heal")
	for i in range(tier + 1 + count_relic("bag")):
		if weights.is_empty():
			break
		var kind = _weighted(weights)
		# Each reward of a chest is different; an eclipse chest always holds a relic.
		if tier == 2 and i == tier and weights.has("relic"):
			kind = "relic"
		weights.erase(kind)
		loot.append(_loot_entry(kind, tier))
	return loot

func _loot_entry(kind: String, tier: int) -> Dictionary:
	match kind:
		"gold": return {"kind": kind, "amount": floor(room_reward() * LOOT_GOLD[tier])}
		"essence": return {"kind": kind, "amount": LOOT_ESSENCE[tier]}
		"heal": return {"kind": kind, "amount": floor(max_hp() * 0.35)}
		"forge": return {"kind": kind, "amount": [0, 2, 3][rng.randi_range(0, 2)]}
		"scrap": return {"kind": kind, "amount": [3, 6, 12][tier]}
		"item": return {"kind": kind, "amount": 1, "item": make_item(["wood", "iron", "eclipse"][tier])}
	return {"kind": kind, "amount": 1}

func loot_text(entry: Dictionary) -> String:
	match entry.kind:
		"gold": return "+%d de oro" % int(entry.amount)
		"essence": return "+%d ascuas" % int(entry.amount)
		"heal": return "+%d de vida" % int(entry.amount)
		"wisp": return "Un lucero se une"
		"forge": return UPGRADES[int(entry.amount)].name + " +1"
		"relic": return "Una reliquia a elegir"
		"chest": return "Un cofre de hierro"
		"scrap": return "+%d esquirlas" % int(entry.amount)
		"item": return item_name(entry.item) + " (" + RARITIES[entry.item.rarity].to_lower() + ")"
		"nothing": return "Nada"
	return ""

func _apply_loot(entry: Dictionary) -> void:
	match entry.kind:
		"gold": _gain_gold(entry.amount)
		"essence": run_essence += int(entry.amount)
		"heal": hp = minf(max_hp(), hp + entry.amount)
		"wisp": wisps += 1
		"forge":
			match int(entry.amount):
				0: blade += 1
				2:
					armor += 1
					hp = minf(max_hp(), hp + 30)
				3: focus += 1
		"relic": _offer_relics()
		"chest":
			journey_phase = "chest"
			chest_tier = 1
		"scrap": scrap += int(entry.amount)
		"item": grant_item(entry.item)

func open_chest() -> Array:
	if journey_phase != "chest" or dead or paused:
		return []
	journey_phase = ""
	total_chests += 1
	progress_mission("chests")
	if total_chests >= 15:
		unlock("chests")
	var loot = roll_loot(chest_tier)
	for entry in loot:
		_apply_loot(entry)
	last_loot = loot
	event.emit(CHEST_NAMES[chest_tier] + " · " + ", ".join(loot.map(func(entry): return loot_text(entry))))
	chest_opened.emit(chest_tier, loot)
	changed.emit()
	return loot

## Pays the bet and lands on one of ten equal sectors.
func _spin_wheel(bet: int) -> void:
	gold -= bet
	total_spins += 1
	if total_spins >= 10:
		unlock("wheel_10")
	wheel_result = rng.randi_range(0, WHEEL.size() - 1)
	var sector: String = WHEEL[wheel_result]
	var entry := {"kind": "nothing", "amount": 0}
	match sector:
		"gold2", "gold3":
			entry = {"kind": "gold", "amount": bet * (2 if sector == "gold2" else 3)}
			if sector == "gold3":
				unlock("jackpot")
		"heal": entry = {"kind": "heal", "amount": floor(max_hp() * 0.5)}
		"essence": entry = {"kind": "essence", "amount": 3}
		"relic": entry = {"kind": "relic", "amount": 1}
		"chest": entry = {"kind": "chest", "amount": 1}
	last_loot = [entry]
	wheel_spun.emit(wheel_result)
	event.emit("Rueda del eclipse · " + WHEEL_NAMES[sector] + ("" if entry.kind == "nothing" else ": " + loot_text(entry)))
	_apply_loot(entry)

func can_accept_encounter() -> bool:
	if journey_phase != "event" or dead or paused:
		return false
	match encounter_kind:
		"shrine": return true
		"merchant", "wheel", "smithy": return gold >= encounter_cost()
		"altar": return hp > encounter_cost()
	return false

func resolve_encounter(accept: bool) -> bool:
	if journey_phase != "event" or dead or paused or (accept and not can_accept_encounter()):
		return false
	var kind = encounter_kind
	var cost = encounter_cost()
	journey_phase = ""
	encounter_kind = ""
	if accept:
		match kind:
			"shrine": hp = minf(max_hp(), hp + max_hp() * shrine_heal())
			"merchant":
				gold -= cost
				wisps += 1
			"altar":
				hp -= cost
				altar_pacts += 1
			"wheel": _spin_wheel(cost)
			"smithy":
				gold -= cost
				for i in range(2):
					_raise_forge(smithy_kind)
		if kind != "wheel":
			event.emit(NODES[kind].name + " · trato completado")
	else:
		event.emit(NODES[kind].name + " · sigues tu camino")
	changed.emit()
	return true

# ---------------------------------------------------------------- arsenal
func _weighted_index(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var roll = rng.randi_range(1, total)
	for i in range(weights.size()):
		roll -= weights[i]
		if roll <= 0:
			return i
	return 0

func make_item(source: String) -> Dictionary:
	var rarity = _weighted_index(RARITY_WEIGHTS[source])
	var base: String = ITEM_IDS[rng.randi_range(0, ITEM_IDS.size() - 1)]
	var quirk = ""
	if rarity == 3 or (rarity == 2 and rng.randf() < 0.4):
		quirk = TRAIT_IDS[rng.randi_range(0, TRAIT_IDS.size() - 1)]
	var item = {"uid": next_item_uid, "base": base, "rarity": rarity, "level": 0, "trait": quirk}
	next_item_uid += 1
	return item

## A found piece joins the arsenal; with the arsenal full it becomes esquirlas.
func grant_item(item: Dictionary) -> void:
	total_items += 1
	remember("item:" + item.base)
	if item.rarity == 3:
		unlock("legendary")
	if armory.size() >= ARMORY_SIZE:
		scrap += salvage_value(item)
		event.emit("Arsenal lleno · %s se funde en %d esquirlas" % [item_name(item), salvage_value(item)])
	else:
		armory.append(item)
		run_items.append(item.uid)
		event.emit("Botín · %s (%s)" % [item_name(item), RARITIES[item.rarity].to_lower()])
	item_found.emit(item)

func item_by_uid(uid: int) -> Dictionary:
	for item in armory:
		if item.uid == uid:
			return item
	return {}

func equipped_item(slot: String) -> Dictionary:
	var uid = int(equipped.get(slot, -1))
	return item_by_uid(uid) if uid >= 0 else {}

func is_equipped(uid: int) -> bool:
	return equipped.values().has(uid)

func item_name(item: Dictionary) -> String:
	return ITEMS[item.base].name

func item_value(item: Dictionary) -> float:
	return ITEMS[item.base].base * RARITY_POWER[item.rarity] * (1.0 + LEVEL_STEP * item.level)

## The piece's effect as text, with its current value.
func item_stat_text(item: Dictionary) -> String:
	var v = item_value(item) * 100.0
	var number = str(roundi(v)) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v).replace(".", ",")
	return STAT_TEXT[ITEMS[item.base].stat] % number

## Sum of an equipped stat (0.1 = 10%).
func gear(stat: String) -> float:
	var total := 0.0
	for slot in SLOTS:
		var item = equipped_item(slot)
		if not item.is_empty() and ITEMS[item.base].stat == stat:
			total += item_value(item)
	return total

func has_trait(id: String) -> bool:
	for slot in SLOTS:
		var item = equipped_item(slot)
		if not item.is_empty() and item["trait"] == id:
			return true
	return false

func max_item_level(item: Dictionary) -> int:
	return RARITY_MAX_LEVEL[item.rarity]

func upgrade_cost(item: Dictionary) -> int:
	return (item.level + 1) * UPGRADE_STEP[item.rarity]

func salvage_value(item: Dictionary) -> int:
	return SALVAGE[item.rarity] + int(item.level * UPGRADE_STEP[item.rarity] * 0.5)

## Pieces can be changed at any time; health never exceeds the new maximum.
func equip(uid: int) -> bool:
	var item = item_by_uid(uid)
	if item.is_empty():
		return false
	equipped[ITEMS[item.base].slot] = uid
	hp = minf(hp, max_hp())
	changed.emit()
	return true

func unequip(slot: String) -> bool:
	if int(equipped.get(slot, -1)) < 0:
		return false
	equipped[slot] = -1
	hp = minf(hp, max_hp())
	changed.emit()
	return true

func upgrade_item(uid: int) -> bool:
	var item = item_by_uid(uid)
	if item.is_empty() or item.level >= max_item_level(item) or scrap < upgrade_cost(item):
		return false
	scrap -= upgrade_cost(item)
	item.level += 1
	if item.level >= max_item_level(item):
		unlock("smith")
	changed.emit()
	return true

## Equipped pieces must be taken off before they are salvaged.
func salvage(uid: int) -> bool:
	var item = item_by_uid(uid)
	if item.is_empty() or is_equipped(uid):
		return false
	scrap += salvage_value(item)
	armory.erase(item)
	run_items.erase(uid)
	changed.emit()
	return true

func mastery(id: String) -> int:
	return int(masteries.get(id, 0))

func mastery_cost(index: int) -> int:
	return MASTERIES[index].cost * (mastery(MASTERIES[index].id) + 1)

func buy_mastery(index: int) -> bool:
	if index < 0 or index >= MASTERIES.size():
		return false
	var id: String = MASTERIES[index].id
	if mastery(id) >= MASTERIES[index].max or scrap < mastery_cost(index):
		return false
	scrap -= mastery_cost(index)
	masteries[id] = mastery(id) + 1
	if mastery(id) >= MASTERIES[index].max:
		unlock("masteries")
	changed.emit()
	return true

## One level of a forge upgrade, as if bought.
func _raise_forge(kind: int) -> void:
	match kind:
		0: blade += 1
		1: wisps += 1
		2:
			armor += 1
			hp = minf(max_hp(), hp + 30)
		3: focus += 1

func buy(kind: int, count: int = 1) -> int:
	if kind < 0 or kind >= UPGRADES.size() or not active() or count < 1:
		return 0
	var bought := 0
	while bought < count and gold >= price(kind):
		gold -= price(kind)
		_raise_forge(kind)
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
	last_banked = banked_preview()
	essence += last_banked
	history.push_front({"room": room, "kills": run_kills, "bosses": run_bosses, "time": int(run_time), "eclipse": eclipse, "oath": oath, "banked": last_banked, "bearer": bearer})
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	dead = true
	bell_resonance = 0
	forge_armor = 0
	pending_hit = 0
	pending_damage = 0
	charging = false
	wall = 0
	wall_time = 0
	summon_time = 0
	burn_time = 0
	ember_active = false
	weak_active = false
	parry_window = 0
	offers.clear()
	journey_phase = ""
	encounter_kind = ""
	runs += 1
	fallen.emit()
	changed.emit()

func buy_legacy(kind: int) -> bool:
	if not can_buy_legacy(kind):
		return false
	essence -= legacy_price(kind)
	legacy[kind] = legacy_level(kind) + 1
	# A first oath is sworn at once; switching later is a free choice.
	if is_oath(kind):
		unlock("oath")
	if is_oath(kind) and oath == -1:
		oath = kind
	changed.emit()
	return true

func restart() -> void:
	run_start_best = best
	room = 1
	gold = legacy_level(4) * 30.0
	blade = 0
	wisps = 1 + mini(legacy_level(9), LEGACY[9].max) + (1 if oath == OATH_SWARM else 0) + int(bearer_stat("start_wisps", 0))
	wall = 0
	wall_time = 0
	summon_time = 0
	last_breath_used = false
	pending_echo = false
	armor = 0
	focus = 0
	relics.clear()
	manual_rest = 0
	shelter_ready = false
	offers.clear()
	journey_phase = ""
	encounter_kind = ""
	altar_pacts = 0
	lanes = []
	lane = -1
	lane_start = 0
	chest_tier = 0
	last_loot = []
	wheel_result = -1
	run_items = []
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
	parry_cooldown = 0
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
	"master_volume", "music_volume", "sfx_volume", "ember_cooldown", "altar_pacts", "run_start_best",
	"eclipse", "eclipse_unlocked", "total_interrupts", "total_armor_breaks", "total_parries", "total_weak",
	"total_chests", "total_spins", "lane_start", "chest_tier", "scrap", "next_item_uid", "total_items",
	"total_missions", "daily_done", "total_time", "smithy_kind"]
const BOOL_KEYS = ["dead", "reduced_motion", "screen_shake", "show_numbers", "fullscreen", "enemy_elite"]
# Older version 1/2 saves omit these fields. Their neutral defaults preserve
# the previous load behavior; new saves resume the exact combat phase.
const COMBAT_DEFAULTS = {"fight_clicks": 0, "manual_rest": 0.0, "shelter_ready": false, "last_breath_used": false, "bell_resonance": 0, "forge_armor": 0.0, "shield_hits": 0, "pending_hit": 0.0, "pending_damage": 0.0, "pending_critical": false, "auto_timer": 0.0, "click_cooldown": 0.0, "combo": 0,
	"combo_time": 0.0, "spawn_delay": 0.0, "stun_time": 0.0,
	"charging": false, "charge_timer": 0.0, "fury_time": 0.0,
	"ember_active": false, "ember_timer": 0.0,
	"parry_window": 0.0, "parry_cooldown": 0.0, "weak_active": false, "weak_timer": 0.0, "weak_cooldown": WEAK_FIRST,
	"wall": 0.0, "wall_time": 0.0, "summon_time": 0.0, "fight_hits": 0, "burn_time": 0.0, "burn_dps": 0.0}
const COMBAT_LIMITS = {"manual_rest": 2.0, "bell_resonance": 3, "shield_hits": 4, "pending_hit": HIT_DELAY, "auto_timer": 1.0, "click_cooldown": CLICK_INTERVAL, "combo": COMBO_BASE + 15,
	"combo_time": 1.5, "spawn_delay": BOSS_INTRO_FULL, "stun_time": 2.0,
	"charge_timer": CHARGE_TIME, "fury_time": 12.0, "ember_timer": 8.0,
	"parry_window": PARRY_WINDOW, "parry_cooldown": PARRY_WHIFF, "weak_timer": WEAK_TIME + 10.0, "burn_time": BURN_TIME, "weak_cooldown": 10.0, "summon_time": SUMMON_TIME, "wall_time": WALL_TIME}

func snapshot() -> Dictionary:
	var data := {"version": SAVE_VERSION, "discoveries": discoveries.duplicate(), "relics": relics, "offers": offers, "legacy": legacy,
		"saved_at": Time.get_unix_time_from_system()}
	for key in NUMBER_KEYS:
		if key != "saved_at":
			data[key] = get(key)
	for key in BOOL_KEYS:
		data[key] = get(key)
	for key in COMBAT_DEFAULTS:
		data[key] = get(key)
	data.ember_pos = [ember_pos.x, ember_pos.y]
	data.weak_pos = [weak_pos.x, weak_pos.y]
	data.oath = oath
	data.achievements = achievements.duplicate()
	data.history = history.duplicate(true)
	data.journey_phase = journey_phase
	data.encounter_kind = encounter_kind
	data.lanes = lanes.duplicate(true)
	data.lane = lane
	data.armory = armory.duplicate(true)
	data.equipped = equipped.duplicate()
	data.masteries = masteries.duplicate()
	data.run_items = run_items.duplicate()
	data.bearer = bearer
	data.affixes = affixes.duplicate()
	data.language = language
	data.achievements_claimed = achievements_claimed.duplicate()
	data.collection_claimed = collection_claimed.duplicate()
	data.bestiary = bestiary.duplicate()
	data.missions = {"day": mission_day, "week": mission_week, "daily": daily.duplicate(true), "weekly": weekly.duplicate(true)}
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
	# Saves before records were tracked per expedition: assume the run began at
	# the stored best, so a resumed run never claims a record it has not earned.
	# Before the Constelación there were no oaths to swear.
	if not data.has("oath"):
		data.oath = -1
	# Before Eclipse, achievements and the expedition log.
	for key in ["eclipse", "eclipse_unlocked", "total_interrupts", "total_armor_breaks", "total_parries", "total_weak", "total_chests", "total_spins", "lane_start", "chest_tier", "scrap", "total_items"]:
		if not data.has(key):
			data[key] = 0
	for key in ["achievements", "history"]:
		if not data.has(key):
			data[key] = []
	if not data.has("run_start_best"):
		data.run_start_best = data.get("best", 1)
	if data.get("legacy") is Array:
		while data.legacy.size() < LEGACY.size():
			data.legacy.append(0)
	for key in COMBAT_DEFAULTS:
		if not data.has(key):
			data[key] = COMBAT_DEFAULTS[key]
	if not data.has("ember_pos"):
		data.ember_pos = [0.5, 0.4]
	if not data.has("weak_pos"):
		data.weak_pos = [0.0, 0.0]
	# Before the arsenal: nothing found or equipped yet.
	if not data.has("armory"):
		data.armory = []
		data.equipped = {"weapon": -1, "talisman": -1, "amulet": -1}
		data.masteries = {}
		data.run_items = []
		data.next_item_uid = 1
	# Before the retos nothing was claimed. Achievements already earned keep
	# their reward waiting.
	if not data.has("achievements_claimed"):
		data.achievements_claimed = []
		data.collection_claimed = []
		data.bestiary = {}
		data.missions = {"day": -1, "week": -1, "daily": [], "weekly": []}
	for key in ["total_missions", "daily_done", "total_time", "smithy_kind"]:
		if not data.has(key):
			data[key] = 0
	# Before the affixes an elite had none.
	if not data.has("affixes"):
		data.affixes = []
	if not data.has("language"):
		data.language = "auto"
	# Before the bearers there was only the Portador.
	if not data.has("bearer"):
		data.bearer = "bearer"
	# Before the map: no lanes. A pending route becomes a map on load.
	if not data.has("lanes"):
		data.lanes = []
		data.lane = -1
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
	if not data.achievements is Array or not data.history is Array or data.history.size() > HISTORY_SIZE:
		return null
	var achievement_ids: Array = ACHIEVEMENTS.map(func(entry): return entry.id)
	for id in data.achievements:
		if not id is String or not achievement_ids.has(id):
			return null
	for run in data.history:
		if not run is Dictionary:
			return null
		for key in ["room", "kills", "bosses", "time", "eclipse", "oath", "banked"]:
			var value = run.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or value != floor(value) or value < (-1 if key == "oath" else 0):
				return null
		if run.has("bearer") and not run.bearer in BEARER_IDS:
			return null
	if not data.has("discoveries"):
		data.discoveries = []
	if not data.discoveries is Array:
		return null
	var known: Array = collection_catalog().map(func(entry): return entry.id)
	for id in data.discoveries:
		if not id is String or not known.has(id):
			return null
	# "route" is the phase of saves made before the map; it carries the
	# encounter it announced and becomes a map when loaded.
	if not data.get("journey_phase") in ["", "route", "map", "event", "chest"] or not data.get("encounter_kind") in [""] + EVENT_NODES:
		return null
	if (data.journey_phase in ["route", "event"]) == data.encounter_kind.is_empty():
		return null
	if not data.lanes is Array or data.lanes.size() > LANES.size() or not (data.lane is float or data.lane is int) or data.lane != floor(data.lane) or data.lane < -1 or data.lane >= data.lanes.size():
		return null
	for nodes in data.lanes:
		if not nodes is Array or nodes.size() != LANE_LENGTH:
			return null
		for node in nodes:
			if not NODES.has(node):
				return null
	if data.journey_phase == "map" and (data.lanes.size() != LANES.size() or data.lane != -1):
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
	if not data.weak_pos is Array or data.weak_pos.size() != 2:
		return null
	for coordinate in data.weak_pos:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or coordinate < -1 or coordinate > 1:
			return null
	for key in ["legacy", "relics", "offers"]:
		if not data.get(key) is Array:
			return null
	if data.altar_pacts != floor(data.altar_pacts) or data.altar_pacts > 10000:
		return null
	if data.journey_phase in ["event", "chest"] and not data.offers.is_empty():
		return null
	if not data.journey_phase.is_empty() and (data.dead or int(data.room) <= 1):
		return null
	if data.journey_phase in ["route", "map"] and (int(data.room) - 1) % 5 != 0:
		return null
	if data.chest_tier != floor(data.chest_tier) or data.chest_tier > 2:
		return null
	if not _valid_arsenal(data):
		return null
	if not data.get("bearer") in BEARER_IDS:
		return null
	if not _valid_retos(data):
		return null
	if not data.affixes is Array or data.affixes.size() > 2 or data.affixes.any(func(id): return not id in AFFIX_IDS):
		return null
	if data.smithy_kind != floor(data.smithy_kind) or data.smithy_kind >= UPGRADES.size():
		return null
	if not data.language in ["auto", "es", "en"]:
		return null
	if not (data.oath is float or data.oath is int) or data.oath != floor(data.oath) or data.oath < -1 or data.oath >= LEGACY.size():
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

static func _valid_retos(data: Dictionary) -> bool:
	if not data.achievements_claimed is Array or not data.collection_claimed is Array or not data.bestiary is Dictionary or not data.missions is Dictionary:
		return false
	for id in data.achievements_claimed:
		if not id is String or not data.achievements.has(id):
			return false
	for category in data.collection_claimed:
		if not category in ["Enemigos", "Reliquias", "Sinergias", "Arsenal"]:
			return false
	for id in data.bestiary:
		var count = data.bestiary[id]
		if not id is String or not (count is float or count is int) or count != floor(count) or count < 0:
			return false
	var m: Dictionary = data.missions
	for key in ["day", "week"]:
		if not (m.get(key) is float or m.get(key) is int) or m[key] != floor(m[key]) or m[key] < -1:
			return false
	for key in ["daily", "weekly"]:
		if not m.get(key) is Array or m[key].size() > (DAILY_COUNT if key == "daily" else WEEKLY_COUNT):
			return false
		for mission in m[key]:
			if not mission is Dictionary or not MISSION_KINDS.has(mission.get("kind")) or not mission.get("claimed") is bool:
				return false
			for field in ["target", "progress"]:
				var value = mission.get(field)
				if not (value is float or value is int) or value != floor(value) or value < 0:
					return false
			if mission.progress > mission.target:
				return false
	return true

static func _valid_arsenal(data: Dictionary) -> bool:
	if not data.armory is Array or data.armory.size() > ARMORY_SIZE or not data.equipped is Dictionary or not data.masteries is Dictionary or not data.run_items is Array:
		return false
	if data.next_item_uid != floor(data.next_item_uid) or data.next_item_uid < 1 or data.scrap != floor(data.scrap):
		return false
	var slots := {}
	for item in data.armory:
		if not item is Dictionary or not ITEMS.has(item.get("base")) or not item.get("trait") in [""] + TRAIT_IDS:
			return false
		for key in ["uid", "rarity", "level"]:
			var value = item.get(key)
			if not (value is float or value is int) or value != floor(value) or value < 0:
				return false
		if item.rarity > 3 or item.level > RARITY_MAX_LEVEL[int(item.rarity)] or item.uid >= data.next_item_uid or slots.has(int(item.uid)):
			return false
		slots[int(item.uid)] = ITEMS[item.base].slot
	if data.equipped.size() != SLOTS.size():
		return false
	for slot in SLOTS:
		var uid = data.equipped.get(slot)
		if not (uid is float or uid is int) or uid != floor(uid) or (uid != -1 and slots.get(int(uid), "") != slot):
			return false
	for id in data.masteries:
		var known := false
		for entry in MASTERIES:
			if entry.id == id:
				var level = data.masteries[id]
				known = (level is float or level is int) and level == floor(level) and level >= 0 and level <= entry.max
		if not known:
			return false
	for uid in data.run_items:
		if not (uid is float or uid is int) or not slots.has(int(uid)):
			return false
	return true

## A save this version cannot read (corrupt, or written by a newer version) is
## copied aside before a fresh expedition overwrites it. Returns the copy.
func preserve_unreadable_save(path: String = SAVE_PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var copy = path.get_basename() + ".ilegible-%d.json" % int(Time.get_unix_time_from_system())
	DirAccess.copy_absolute(path, copy)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.copy_absolute(path + ".bak", copy + ".bak")
	return copy

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
	achievements = data.achievements.duplicate()
	history = []
	for run in data.history:
		var entry := {}
		for key in ["room", "kills", "bosses", "time", "eclipse", "oath", "banked"]:
			entry[key] = int(run[key])
		entry.bearer = run.get("bearer", "bearer")
		history.append(entry)
	eclipse_unlocked = mini(eclipse_unlocked, ECLIPSE_MAX)
	eclipse = mini(eclipse, eclipse_unlocked)
	discoveries = []
	for id in data.discoveries:
		remember(id)
	legacy = data.legacy.map(func(v): return int(v))
	oath = int(data.oath)
	if oath != -1 and (not is_oath(oath) or legacy_level(oath) <= 0):
		oath = -1
	unlock_earned()
	relics = data.relics.duplicate()
	remember_relics()
	offers = data.offers.map(func(v): return int(v))
	journey_phase = data.journey_phase
	encounter_kind = data.encounter_kind
	lanes = data.lanes.duplicate(true)
	lane = int(data.lane)
	armory = []
	for item in data.armory:
		armory.append({"uid": int(item.uid), "base": item.base, "rarity": int(item.rarity), "level": int(item.level), "trait": item["trait"]})
	equipped = {}
	for slot in SLOTS:
		equipped[slot] = int(data.equipped[slot])
	masteries = {}
	for id in data.masteries:
		masteries[id] = int(data.masteries[id])
	run_items = data.run_items.map(func(uid): return int(uid))
	bearer = data.bearer if bearer_unlocked_by(data.bearer) else "bearer"
	language = data.language
	achievements_claimed = data.achievements_claimed.duplicate()
	collection_claimed = data.collection_claimed.duplicate()
	bestiary = {}
	for id in data.bestiary:
		bestiary[id] = int(data.bestiary[id])
	mission_day = int(data.missions.day)
	mission_week = int(data.missions.week)
	daily = []
	weekly = []
	for key in ["daily", "weekly"]:
		for mission in data.missions[key]:
			var entry = {"kind": mission.kind, "target": int(mission.target), "progress": int(mission.progress), "claimed": mission.claimed}
			(daily if key == "daily" else weekly).append(entry)
	var boss_count = boss_attacks
	spawn_enemy(false)
	boss_attacks = boss_count
	for key in COMBAT_DEFAULTS:
		set(key, int(data[key]) if COMBAT_DEFAULTS[key] is int else data[key])
	ember_pos = Vector2(float(data.ember_pos[0]), float(data.ember_pos[1]))
	# Respawning above rolled new affixes; the saved rival keeps its own.
	affixes = data.affixes.duplicate() if enemy_elite else []
	weak_pos = Vector2(float(data.weak_pos[0]), float(data.weak_pos[1]))
	if journey_phase == "route":
		journey_phase = "map"
		encounter_kind = ""
		make_lanes(room)
	forge_armor = clampf(forge_armor, 0, forge_armor_max()) if charging and is_forge_keeper() else 0.0
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

## Only surpassing the best room known when the expedition began is a record.
func is_record() -> bool:
	return runs > 1 and room > run_start_best
