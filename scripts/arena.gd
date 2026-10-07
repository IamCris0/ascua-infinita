extends Control
## The battle stage: Gemini backgrounds, animated actors, effects and the
## in-world HUD (enemy plate, telegraphs, banners, damage numbers).
## Stage coordinates are the background's own 1024 x 800 pixel space.

signal clicked
signal ember_clicked
signal coins(screen_pos: Vector2, amount: int, essence: int)

const Actor = preload("res://scripts/actor.gd")
const STAGE_SIZE = Vector2(1024, 800)
const HERO_FEET = Vector2(300, 652)
const ENEMY_FEET = Vector2(745, 640)
const LIGHTS = [
	[[Vector2(203, 488), Color(1.0, 0.55, 0.2), 170.0], [Vector2(898, 484), Color(1.0, 0.55, 0.2), 110.0], [Vector2(515, 108), Color(0.6, 0.4, 1.0), 120.0], [Vector2(745, 625), Color(0.35, 0.95, 0.7), 150.0]],
	[[Vector2(200, 468), Color(0.75, 0.6, 1.0), 170.0], [Vector2(515, 98), Color(0.6, 0.4, 1.0), 130.0], [Vector2(745, 625), Color(0.7, 0.5, 1.0), 150.0]],
	[[Vector2(215, 455), Color(1.0, 0.5, 0.15), 190.0], [Vector2(855, 520), Color(1.0, 0.45, 0.1), 230.0], [Vector2(510, 238), Color(1.0, 0.7, 0.25), 170.0], [Vector2(745, 625), Color(1.0, 0.75, 0.3), 150.0]]
]
# Hue shift (turns) and tint for each enemy in each biome.
const VARIANTS = {
	"slime": [[0.0, Color.WHITE, 1.0], [0.24, Color(0.9, 0.95, 1.1), 1.0], [-0.36, Color(1.1, 0.95, 0.9), 1.0]],
	"wisp": [[0.0, Color.WHITE, 1.0], [-0.12, Color(0.92, 1.0, 1.15), 1.1], [0.0, Color(1.45, 0.8, 0.55), 1.25]],
	"sentinel": [[0.0, Color.WHITE, 1.0], [0.0, Color(0.86, 0.86, 1.22), 1.0], [0.0, Color(1.15, 0.92, 0.85), 1.0]],
	"boss": [[0.0, Color.WHITE, 1.0], [0.72, Color(0.95, 0.95, 1.1), 1.0], [0.08, Color(1.1, 1.0, 0.92), 1.0]],
	"bell": [[0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0]],
	"forge": [[0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0]],
	"guardian": [[0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0]],
	"acolyte": [[0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0], [0.0, Color.WHITE, 1.0]]
}
# Actor keys drawn as bosses: larger, slower entrance, wider shadow.
const BOSS_KEYS = ["boss", "bell", "forge"]
const PARTICLE_COLORS = {"slime": [Color("74d9a8"), Color("2f6b55")], "wisp": [Color("c9a6f5"), Color("fff3c8")],
	"sentinel": [Color("7e8796"), Color("ff9a4a")], "boss": [Color("ff7a3d"), Color("8c2f2f")],
	"bell": [Color("c9a6f5"), Color("4b3f73")], "forge": [Color("ff8a3d"), Color("3a2a24")],
	"guardian": [Color("5fb4ff"), Color("4a4f5c")], "acolyte": [Color("c9a6f5"), Color("2e2440")]}

var state
var lib
var reduced_motion: bool = false
var shake_enabled: bool = true
var show_numbers: bool = true
var stage: Node2D
var backdrop: Node2D
var lights: Node2D
var fx_layer: Node2D
var overlay: Control
var hero
var enemy
var corpse
var glow: Texture2D
var time: float = 0.0
var ambient_time: float = 0.0
var shake: float = 0.0
var flash: float = 0.0
var hurt_vignette: float = 0.0
var bg_index: int = 0
var bg_prev: int = 0
var bg_fade: float = 0.0
var particles: Array = []
var effects: Array = []
var numbers: Array = []
var rings: Array = []
var projectiles: Array = []
var ash: Array = []
var banner: Dictionary = {}
var shown_kind: String = ""
var enemy_attacking: bool = false
var auto_launched: bool = false
var heavy_launched: bool = false
var hp_trail: float = 1.0
var hovered: bool = false
var last_hurt_anim: float = 0.0
var hint_alpha: float = 1.0

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	lib = load("res://scripts/art_library.gd").shared()
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	glow = gt
	stage = Node2D.new()
	add_child(stage)
	backdrop = Node2D.new()
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.draw.connect(_draw_backdrop)
	stage.add_child(backdrop)
	lights = Node2D.new()
	var add = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lights.material = add
	lights.draw.connect(_draw_lights)
	stage.add_child(lights)
	corpse = Actor.new(lib, "slime")
	corpse.alpha = 0.0
	stage.add_child(corpse)
	enemy = Actor.new(lib, "slime")
	enemy.position = ENEMY_FEET
	stage.add_child(enemy)
	hero = Actor.new(lib, "hero")
	hero.position = HERO_FEET
	stage.add_child(hero)
	fx_layer = Node2D.new()
	fx_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx_layer.draw.connect(_draw_fx)
	stage.add_child(fx_layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	for i in range(28):
		ash.append({"pos": Vector2(randf() * 1024, randf() * 800), "speed": randf_range(8, 22), "phase": randf() * TAU, "size": randf_range(1.5, 3.5)})
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	resized.connect(_layout)
	if state != null:
		sync_enemy(false)
		bg_index = state.biome()
		bg_prev = bg_index
	_layout()

func _layout() -> void:
	if stage == null or size.x <= 0 or size.y <= 0:
		return
	var s: float
	var origin := Vector2.ZERO
	if size.x / size.y >= STAGE_SIZE.x / STAGE_SIZE.y:
		s = size.x / STAGE_SIZE.x
		var visible_h = size.y / s
		var top = clampf((STAGE_SIZE.y - visible_h) * 0.78, 0, STAGE_SIZE.y - visible_h)
		origin = Vector2(0, -top * s)
	else:
		s = size.y / STAGE_SIZE.y
		var visible_w = size.x / s
		var left = clampf(522 - visible_w * 0.5, 0, STAGE_SIZE.x - visible_w)
		origin = Vector2(-left * s, 0)
	stage.scale = Vector2(s, s)
	stage.position = origin
	stage.set_meta("origin", origin)

func stage_to_screen(p: Vector2) -> Vector2:
	return stage.position + p * stage.scale

func visible_stage_rect() -> Rect2:
	var origin: Vector2 = stage.get_meta("origin", Vector2.ZERO)
	return Rect2(-origin / stage.scale, size / stage.scale)

## Bosses of the Criptas and the Forja and the two special roles have their
## own sheets; every other enemy uses its kind's sheet.
func actor_key() -> String:
	if state.is_bell_keeper():
		return "bell"
	if state.is_forge_keeper():
		return "forge"
	if state.enemy_role() in ["guardian", "acolyte"]:
		return state.enemy_role()
	return state.enemy_kind()

func enemy_center() -> Vector2:
	return enemy.position + Vector2(enemy.offset.x, -enemy.height() * 0.5)

func hero_center() -> Vector2:
	return hero.position + Vector2(hero.offset.x + 10, -hero.height() * 0.5)

func ember_stage_pos() -> Vector2:
	var r = visible_stage_rect()
	return r.position + r.size * state.ember_pos + Vector2(0, sin(ambient_time * 2.2) * 8)

# ---------------------------------------------------------------- input
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if state != null and state.ember_active and e.position.distance_to(stage_to_screen(ember_stage_pos())) < 46:
			ember_clicked.emit()
		else:
			clicked.emit()
		accept_event()

# ---------------------------------------------------------------- reactions
func sync_enemy(walk_in: bool = true) -> void:
	projectiles.clear()
	auto_launched = false
	heavy_launched = false
	var kind: String = actor_key()
	# A new actor must not inherit the defeated enemy's lunge or arrival.
	for tag in ["lunge", "walk_in", "walking"]:
		if enemy.has_meta(tag):
			enemy.remove_meta(tag)
	enemy.offset = Vector2.ZERO
	enemy.speed = 1.0
	enemy.set_character(kind)
	var variant = VARIANTS[kind][state.biome()]
	enemy.hue = variant[0]
	enemy.tint = variant[1]
	enemy.saturation = variant[2]
	enemy.alpha = 1.0
	enemy.brightness = 1.12 if state.enemy_elite else 1.0
	enemy.base_scale = 1.15 if kind in BOSS_KEYS else (1.12 if state.enemy_elite else 1.0)
	enemy.bob = 10.0 if kind == "wisp" and not reduced_motion else 0.0
	enemy.position = ENEMY_FEET + (Vector2(0, -34) if kind == "wisp" else Vector2.ZERO)
	enemy.flash = 0
	enemy_attacking = false
	hp_trail = 1.0
	shown_kind = kind
	if walk_in:
		var distance = 420.0 if kind in BOSS_KEYS else 300.0
		enemy.offset = Vector2(distance, 0)
		enemy.play("walk")
		enemy.set_meta("walk_in", distance)
	if state.biome() != bg_index:
		bg_prev = bg_index
		bg_index = state.biome()
		bg_fade = 1.0
		show_banner(state.BIOMES[bg_index], state.BIOME_RULES[bg_index], Color("84cdb7"))
	if kind in BOSS_KEYS:
		show_banner(state.enemy_name(), state.boss_title(), Color("ff8a5c"), 1.9)

func show_banner(title: String, subtitle: String, color: Color, duration: float = 3.2) -> void:
	banner = {"title": title, "subtitle": subtitle, "color": color, "t": 0.0, "dur": duration}

func on_shield_broken() -> void:
	var at = enemy_center()
	rings.append({"pos": at, "t": 0.0, "dur": 0.4, "radius": 120.0, "color": Color("82bcf5")})
	burst_particles(at, [Color("82bcf5"), Color("e0f4ff")], 16, 250.0)

func on_armor_broken() -> void:
	var at = enemy_center()
	projectiles = projectiles.filter(func(p): return not p.get("fire", false))
	rings.append({"pos": at, "t": 0.0, "dur": 0.5, "radius": 200.0, "color": Color("ff9a4a")})
	burst_particles(at, [Color("ff9a4a"), Color("ffd28a"), Color("5a5f6b")], 30, 420.0)
	add_shake(8.0)
	enemy.play("hurt")
	show_banner("¡CORAZA ROTA!", state.enemy_name() + " queda aturdido", Color("ffb070"), 1.6)

func on_attack_started() -> void:
	hero.play("attack")

func on_struck(damage: float, critical: bool, automatic: bool) -> void:
	var at = enemy_center() + Vector2(randf_range(-18, 18), randf_range(-24, 18))
	if automatic:
		effects.append({"name": "magic", "t": 0.0, "pos": at, "size": 120.0, "rot": 0.0, "color": Color(1, 1, 1, 0.9)})
		auto_launched = false
		enemy.flash = maxf(enemy.flash, 0.25)
		enemy.flash_color = Color("c8ffe9")
	else:
		if not hero.playing("attack"):
			hero.play("attack")
		hero.anim_time = state.HIT_DELAY
		hero.offset = Vector2(ENEMY_FEET.x - HERO_FEET.x - 125, 0)
		var rot = randf_range(-0.7, 0.5)
		effects.append({"name": "blade_arc", "t": 0.0, "pos": at, "size": 150.0 if critical else 110.0, "rot": rot, "color": Color("baffd9")})
		if critical:
			effects.append({"name": "critical", "t": 0.0, "pos": at, "size": 210.0, "rot": 0.0, "color": Color(1, 1, 1)})
			add_shake(5.0)
		enemy.flash = 0.85
		enemy.flash_color = Color(1, 0.96, 0.88)
		enemy.offset += Vector2(10 if not critical else 18, 0)
		if not enemy_attacking and time - last_hurt_anim > 0.45 and not enemy.has_meta("walking"):
			enemy.play("hurt")
			last_hurt_anim = time
	burst_particles(at, PARTICLE_COLORS.get(enemy.key, [Color.WHITE, Color.GRAY]), 10 if critical else (3 if automatic else 6), 260.0)
	if show_numbers:
		var text = compact_number(damage) + ("!" if critical else "")
		var color = Color("ffcf7b") if critical else (Color("86e0bd") if automatic else Color("f6efe0"))
		numbers.append({"pos": at + Vector2(randf_range(-30, 30), -40), "vel": Vector2(randf_range(-20, 20), -95), "life": 1.0, "text": text, "color": color, "size": 34 if critical else (20 if automatic else 26)})
	hint_alpha = maxf(0.0, hint_alpha - 0.12)

func on_burst(interrupted: bool) -> void:
	hero.play("attack")
	hero.anim_time = state.HIT_DELAY
	flash = 0.0 if reduced_motion else 0.55
	add_shake(9.0)
	var at = enemy_center()
	effects.append({"name": "critical", "t": 0.0, "pos": at, "size": 380.0, "rot": 0.0, "color": Color(1, 1, 1)})
	effects.append({"name": "embers", "t": 0.0, "pos": at + Vector2(0, -30), "size": 300.0, "rot": 0.0, "color": Color(1, 1, 1)})
	rings.append({"pos": at, "t": 0.0, "dur": 0.6, "radius": 260.0, "color": Color("ffcf7b")})
	rings.append({"pos": hero_center(), "t": 0.0, "dur": 0.2, "radius": 100.0, "color": Color("fff1cf")})
	burst_particles(at, [Color("ffcf7b"), Color("ff8a3d"), Color("fff1cf")], 34, 520.0)
	if interrupted:
		projectiles = projectiles.filter(func(p): return not p.get("fire", false))
		enemy.play("hurt")
		show_banner("¡INTERRUMPIDO!", state.enemy_name() + " queda aturdido", Color("ffcf7b"), 1.6)

func on_hero_hit(damage: float, heavy: bool) -> void:
	enemy.play("attack")
	enemy.anim_time = lib.anim_length(enemy.key, "attack") * 0.5
	hero.play("hurt")
	hero.flash = 0.75
	hero.flash_color = Color(1, 0.3, 0.25)
	hero.offset = Vector2(-16 if not heavy else -30, 0)
	hurt_vignette = 1.0 if heavy else 0.6
	add_shake(12.0 if heavy else 6.0)
	burst_particles(hero_center(), [Color("ff6a4a"), Color("ffcf7b")], 16 if heavy else 8, 240.0)
	if heavy:
		effects.append({"name": "critical", "t": 0.0, "pos": hero_center(), "size": 300.0, "rot": 0.0, "color": Color(1, 0.7, 0.6)})
	if show_numbers:
		numbers.append({"pos": hero_center() + Vector2(0, -60), "vel": Vector2(-20, -80), "life": 1.1, "text": "-" + compact_number(damage), "color": Color("ff6b5b"), "size": 34 if heavy else 26})

func on_enemy_defeated(_kind: String, elite: bool, boss: bool) -> void:
	# Still the defeated actor: the next enemy is synced after this signal.
	var kind: String = enemy.key
	corpse.set_character(kind)
	corpse.hue = enemy.hue
	corpse.tint = enemy.tint
	corpse.saturation = enemy.saturation
	corpse.base_scale = enemy.base_scale
	corpse.brightness = enemy.brightness
	corpse.position = enemy.position
	corpse.offset = Vector2.ZERO
	corpse.alpha = 1.0
	corpse.flash = 0.6
	corpse.play("death", "death", true)
	var at = enemy_center()
	effects.append({"name": "embers", "t": 0.0, "pos": at, "size": 260.0 if boss else 180.0, "rot": 0.0, "color": Color(1, 1, 1)})
	burst_particles(at, PARTICLE_COLORS.get(kind, [Color.WHITE]) + [Color("ffcf7b")], 40 if boss else 18, 380.0)
	if boss:
		rings.append({"pos": at, "t": 0.0, "dur": 1.0, "radius": 420.0, "color": Color("ff8a5c")})
		add_shake(14.0)
		flash = 0.0 if reduced_motion else 0.4
	var amount = 14 if boss else (8 if elite else 4)
	var essence = 5 if boss else (2 if elite else 1)
	coins.emit(global_position + stage_to_screen(at), amount, essence)

func on_fallen() -> void:
	hero.play("death", "death", true)
	add_shake(10.0)
	burst_particles(hero_center(), [Color("86e0bd"), Color("ff8a3d")], 30, 200.0)

func on_restart() -> void:
	hero.play("idle")
	hero.alpha = 1.0
	corpse.alpha = 0.0
	particles.clear()
	effects.clear()
	numbers.clear()
	projectiles.clear()
	hint_alpha = 1.0
	sync_enemy(true)

func on_echo_strike() -> void:
	var at = enemy_center()
	rings.append({"pos": at, "t": 0.0, "dur": 0.45, "radius": 170.0, "color": Color("baffd9")})
	numbers.append({"pos": at + Vector2(0, -90), "vel": Vector2(0, -70), "life": 1.0, "text": "¡ECO ×3!", "color": Color("baffd9"), "size": 30})
	add_shake(6.0)

func on_last_breath() -> void:
	flash = 0.0 if reduced_motion else 0.5
	rings.append({"pos": hero_center(), "t": 0.0, "dur": 0.8, "radius": 240.0, "color": Color("86e0bd")})
	burst_particles(hero_center(), [Color("86e0bd"), Color("fff1cf")], 30, 300.0)
	hero.play("hurt")
	show_banner("ÚLTIMO ALIENTO", "La brasa se niega a apagarse · Destello listo", Color("86e0bd"), 2.0)

func on_ember_collected(kind: String) -> void:
	var at = ember_stage_pos()
	effects.append({"name": "magic" if kind == "heal" else "critical", "t": 0.0, "pos": at, "size": 200.0, "rot": 0.0, "color": Color(1, 1, 1)})
	rings.append({"pos": at, "t": 0.0, "dur": 0.5, "radius": 140.0, "color": Color("ffcf7b")})
	burst_particles(at, [Color("ffcf7b"), Color("ff9a4a")], 20, 300.0)
	var labels = {"gold": "¡ORO!", "fury": "¡FURIA!", "heal": "¡VIDA!", "spark": "¡DESTELLO!"}
	numbers.append({"pos": at + Vector2(0, -30), "vel": Vector2(0, -60), "life": 1.4, "text": labels.get(kind, "¡ASCUA!"), "color": Color("ffcf7b"), "size": 30})
	if kind == "gold":
		coins.emit(global_position + stage_to_screen(at), 10, 0)

func add_shake(amount: float) -> void:
	if shake_enabled and not reduced_motion:
		shake = maxf(shake, amount)

func burst_particles(at: Vector2, palette: Array, count: int, power: float) -> void:
	if reduced_motion:
		count = int(count / 2.0)
	for i in range(count):
		var angle = randf_range(-PI, 0.2) if randf() < 0.8 else randf() * TAU
		var v = Vector2(cos(angle), sin(angle)) * randf_range(power * 0.3, power)
		particles.append({"pos": at, "vel": v, "life": randf_range(0.35, 0.8), "max": 0.8, "color": palette[randi() % palette.size()], "size": randf_range(3, 7)})

func companion_pos(i: int) -> Vector2:
	var count = mini(state.wisps, 6)
	var a = ambient_time * 1.6 + i * TAU / maxf(1, count)
	return HERO_FEET + Vector2(cos(a) * 78, -96 + sin(a) * 26)

# ---------------------------------------------------------------- update
func _process(delta: float) -> void:
	if state == null:
		return
	var frozen: bool = not state.active() and not state.dead
	if reduced_motion:
		enemy.bob = 0
		shake = 0
		flash = 0
	hero.animation_paused = frozen
	enemy.animation_paused = frozen
	corpse.animation_paused = frozen
	if frozen:
		return
	if hero.playing("attack"):
		var phase = clampf(hero.anim_time / state.CLICK_INTERVAL, 0, 1)
		hero.offset.x = sin(phase * PI) * (ENEMY_FEET.x - HERO_FEET.x - 125)
	time += delta
	if not reduced_motion:
		ambient_time += delta
	enemy.bob = 10.0 if enemy.key == "wisp" and not reduced_motion else 0.0
	if reduced_motion:
		shake = 0.0
		flash = 0.0
	shake = maxf(0.0, shake - delta * 30.0)
	flash = maxf(0.0, flash - delta * 2.2)
	hurt_vignette = maxf(0.0, hurt_vignette - delta * 1.6)
	bg_fade = maxf(0.0, bg_fade - delta * 0.8)
	if not banner.is_empty():
		banner.t += delta
		if banner.t > banner.dur:
			banner = {}
	var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	stage.position = stage.get_meta("origin", Vector2.ZERO) + shake_offset
	if shown_kind != actor_key():
		sync_enemy(true)
	# Walk-in for a freshly spawned enemy.
	if enemy.has_meta("walk_in"):
		var distance: float = enemy.get_meta("walk_in")
		var total = state.BOSS_INTRO if state.is_boss() else state.SPAWN_DELAY
		var k = clampf(state.spawn_delay / total, 0, 1) if total > 0 else 0.0
		enemy.offset = Vector2(distance * k, 0)
		enemy.set_meta("walking", true)
		if state.spawn_delay <= 0:
			enemy.remove_meta("walk_in")
			enemy.remove_meta("walking")
			enemy.play("idle")
	for p in projectiles:
		p.t += delta
	projectiles = projectiles.filter(func(p): return p.t < p.dur)
	# Travel precedes damage; remaining simulation time determines arrival.
	if state.can_strike():
		var interval: float = state.wisp_interval()
		if state.auto_timer < interval * 0.7:
			auto_launched = false
		if state.auto_timer >= interval * 0.78 and not auto_launched and state.auto_damage() > 0:
			auto_launched = true
			for i in range(mini(state.wisps, 6)):
				projectiles.append({"from": companion_pos(i), "to": enemy_center(), "t": 0.0, "dur": maxf(0.01, interval - state.auto_timer), "color": Color("86e0bd"), "size": 4.0})
	if not state.charging:
		heavy_launched = false
	elif state.charge_timer <= 0.32 and not heavy_launched:
		heavy_launched = true
		projectiles.append({"from": enemy_center() + Vector2(-60, -10), "to": hero_center(), "t": 0.0, "dur": maxf(0.01, state.charge_timer), "color": Color("c9a6f5") if state.enemy_role() == "acolyte" or state.is_bell_keeper() else Color("ff9a4a"), "size": 26.0, "fire": true, "echo": state.is_bell_keeper()})
	# Enemy wind-up: start the attack animation just before the blow lands.
	if state.active() and state.spawn_delay <= 0 and not state.charging and state.stun_time <= 0:
		var left = state.attack_interval() - state.attack_timer
		var windup = lib.anim_length(enemy.key, "attack") * 0.5
		if left < windup and not enemy_attacking:
			enemy_attacking = true
			enemy.play("attack")
			if enemy.key in ["slime", "wisp"]:
				enemy.set_meta("lunge", 0.0)
		if left < windup:
			enemy.anim_time = maxf(0, windup - left)
		elif left > 0.5:
			enemy_attacking = false
	if state.charging and not enemy.playing("attack"):
		enemy.play("attack")
	if state.charging:
		enemy.anim_time = 0.1 if state.charge_timer > 0.32 else 0.3 + (0.32 - state.charge_timer)
		enemy.flash = maxf(enemy.flash, 0.25 + 0.2 * sin(ambient_time * 14.0))
		enemy.flash_color = Color("c9a6f5") if state.is_bell_keeper() else Color(1, 0.55, 0.2)
	if enemy.has_meta("lunge"):
		var t: float = enemy.get_meta("lunge") + delta
		enemy.set_meta("lunge", t)
		enemy.offset.x = -sin(clampf(t / 0.45, 0, 1) * PI) * (55 if reduced_motion else 110)
		if t >= 0.45:
			enemy.remove_meta("lunge")
	if state.stun_time > 0:
		enemy.speed = 0.25
	else:
		enemy.speed = 1.0
	corpse.alpha = maxf(0.0, corpse.alpha - delta * (0.55 if corpse.key in BOSS_KEYS else 1.1))
	hero.brightness = 1.0 + (0.18 + 0.08 * sin(ambient_time * 10.0) if state.fury_time > 0 else 0.0)
	var ratio = state.enemy_hp / maxf(1.0, state.enemy_max)
	hp_trail = maxf(ratio, hp_trail - delta * 0.7)
	for p in particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel.y += 620 * delta
		p.vel *= 0.985
	particles = particles.filter(func(p): return p.life > 0)
	for e in effects:
		e.t += delta
	effects = effects.filter(func(e): return e.t < 0.6)
	for r in rings:
		r.t += delta
	rings = rings.filter(func(r): return r.t < r.dur)
	for n in numbers:
		n.life -= delta
		n.pos += n.vel * delta
		n.vel.y += 60 * delta
	numbers = numbers.filter(func(n): return n.life > 0)
	for a in ash:
		if reduced_motion:
			break
		a.pos.y -= a.speed * delta
		a.pos.x += sin(ambient_time * 0.7 + a.phase) * 10 * delta
		if a.pos.y < -10:
			a.pos = Vector2(randf() * 1024, 810)
	backdrop.queue_redraw()
	lights.queue_redraw()
	fx_layer.queue_redraw()
	overlay.queue_redraw()

# ---------------------------------------------------------------- drawing
func _draw_backdrop() -> void:
	var rect = Rect2(Vector2.ZERO, STAGE_SIZE)
	backdrop.draw_texture_rect(lib.backgrounds[bg_index], rect, false)
	if bg_fade > 0:
		backdrop.draw_texture_rect(lib.backgrounds[bg_prev], rect, false, Color(1, 1, 1, bg_fade))
	# Ground shadows under the actors.
	_ellipse(backdrop, HERO_FEET + Vector2(hero.offset.x, 2), Vector2(62, 12), Color(0, 0, 0, 0.45))
	var ew = 110.0 if enemy.key in BOSS_KEYS else 70.0
	_ellipse(backdrop, ENEMY_FEET + Vector2(enemy.offset.x, 2), Vector2(ew, 14), Color(0, 0, 0, 0.45))

func _ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(24):
		var a = i * TAU / 24
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	canvas.draw_colored_polygon(pts, color)

func _draw_lights() -> void:
	for light in LIGHTS[bg_index]:
		var flicker = 1.0 + 0.08 * sin(ambient_time * 9.0 + light[0].x) + 0.05 * sin(ambient_time * 23.0 + light[0].y)
		var r: float = light[2] * flicker
		lights.draw_texture_rect(glow, Rect2(light[0] - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(light[1], 0.32))
	var core = 105.0 + 6.0 * sin(ambient_time * 3.0)
	lights.draw_texture_rect(glow, Rect2(HERO_FEET + Vector2(0, -80) - Vector2.ONE * core, Vector2.ONE * core * 2), false, Color(0.45, 1.0, 0.8, 0.22))
	for a in ash:
		var c = Color(1.0, 0.6, 0.3, 0.55) if bg_index != 1 else Color(0.75, 0.6, 1.0, 0.5)
		lights.draw_rect(Rect2(a.pos, Vector2.ONE * a.size), c)
	if state.enemy_elite and state.spawn_delay <= 0:
		var r = 140.0 + 10 * sin(ambient_time * 4.0)
		lights.draw_texture_rect(glow, Rect2(enemy_center() - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(1.0, 0.75, 0.25, 0.55))
	if state.charging:
		var r = 120.0 + 160.0 * state.charge_progress()
		lights.draw_texture_rect(glow, Rect2(enemy_center() + Vector2(-70, -10) - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(0.65, 0.4, 1.0, 0.5) if state.is_bell_keeper() else Color(1.0, 0.45, 0.1, 0.7))
	if state.fury_time > 0:
		var r = 130.0
		lights.draw_texture_rect(glow, Rect2(hero_center() - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(1.0, 0.5, 0.2, 0.45))
	if state.ember_active:
		var r = 70.0 + 8 * sin(ambient_time * 6.0)
		lights.draw_texture_rect(glow, Rect2(ember_stage_pos() - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(1.0, 0.7, 0.3, 0.9))

func _draw_fx() -> void:
	# The four arcs mirror the shield segments that still absorb hits.
	if state.shield_hits > 0:
		var center = enemy_center()
		for i in range(state.shield_hits):
			var angle = -PI * 0.75 + i * PI * 0.5
			fx_layer.draw_arc(center, 85, angle, angle + PI * 0.4, 12, Color("82bcf5"), 5)
	# Molten armour: the ring shrinks as hits crack it.
	if state.forge_armor > 0:
		var center = enemy_center()
		var k = state.forge_armor / maxf(1.0, state.forge_armor_max())
		var heat = 0.75 + 0.25 * sin(ambient_time * 10.0)
		fx_layer.draw_arc(center, 96, 0, TAU, 48, Color(0.15, 0.08, 0.05, 0.6), 14)
		fx_layer.draw_arc(center, 96, -PI / 2, -PI / 2 + TAU * k, 48, Color(1.0, 0.45 + 0.25 * heat, 0.15), 10)
	# Companions orbiting the bearer.
	for i in range(mini(state.wisps, 6)):
		var pos = companion_pos(i)
		var frame = lib.frame_at("companion", "idle", ambient_time + i * 0.3)
		lib.draw_frame(fx_layer, "companion", frame, pos, 1.0)
	for p in projectiles:
		var k = clampf(p.t / p.dur, 0, 1)
		var pos = p.from.lerp(p.to, k) + Vector2(0, -sin(k * PI) * (40 if p.get("fire", false) else 12))
		if p.get("echo", false):
			fx_layer.draw_arc(pos, 20 + k * 35, 0, TAU, 24, Color(p.color, 0.85), 4)
		elif p.get("fire", false):
			lib.draw_fx(fx_layer, "critical", fmod(time, 0.2), pos, p.size * 5, p.color, 20.0, time * 6.0)
		else:
			fx_layer.draw_line(p.from.lerp(p.to, maxf(0, k - 0.25)), pos, Color(p.color, 0.8), p.size)
	for e in effects:
		if e.name == "blade_arc":
			var opacity = maxf(0, 1.0 - e.t / 0.18)
			fx_layer.draw_arc(e.pos - Vector2(e.size * 0.3, 0), e.size * 0.4, -1.1 + e.rot, 1.1 + e.rot, 16, Color(e.color, opacity), 4.0)
		else:
			lib.draw_fx(fx_layer, e.name, e.t, e.pos, e.size, e.color, 13.0, e.rot)
	for p in particles:
		var a = clampf(p.life / 0.4, 0, 1)
		fx_layer.draw_rect(Rect2(p.pos - Vector2.ONE * p.size * 0.5, Vector2.ONE * p.size), Color(p.color, a))
	for r in rings:
		var k = r.t / r.dur
		fx_layer.draw_arc(r.pos, r.radius * ease(k, 0.4), 0, TAU, 48, Color(r.color, 1.0 - k), 6.0 * (1.0 - k) + 1.0)
	if state.ember_active:
		var at = ember_stage_pos()
		lib.draw_fx(fx_layer, "embers", fmod(ambient_time, 0.3), at + Vector2(0, -18), 110.0, Color(1, 1, 1, 0.9), 13.0)
		fx_layer.draw_circle(at, 15.0, Color("ff9a4a"))
		fx_layer.draw_circle(at, 9.0, Color("ffe7a8"))
		fx_layer.draw_arc(at, 30.0, -PI / 2, -PI / 2 + TAU * state.ember_timer / 8.0, 32, Color(1, 0.85, 0.5, 0.85), 3.0)
	if state.stun_time > 0:
		var top = enemy_center() + Vector2(0, -enemy.height() * 0.55)
		for i in range(3):
			var a = ambient_time * 4.0 + i * TAU / 3
			lib.draw_fx(fx_layer, "critical", 0.08, top + Vector2(cos(a) * 46, sin(a) * 12), 54.0, Color(1, 0.95, 0.6), 14.0)

func _draw_overlay() -> void:
	var font: Font = lib.heading_font
	var body: Font = ThemeDB.fallback_font
	var w = size.x
	# Screen-space vignettes.
	if hurt_vignette > 0 or (state.hp < state.max_hp() * 0.3 and not state.dead):
		var low = 0.25 + 0.15 * sin(ambient_time * 5.0) if state.hp < state.max_hp() * 0.3 and not state.dead else 0.0
		var a = maxf(hurt_vignette * 0.55, low)
		_frame_glow(Color(0.85, 0.08, 0.05, a))
	if flash > 0:
		overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.93, 0.75, flash * 0.6))
	# Enemy plate.
	if state.spawn_delay <= 0 or not state.is_boss():
		var head = stage_to_screen(enemy.position + Vector2(enemy.offset.x, -enemy.height() - 26 - (enemy.bob)))
		var plate_w = clampf(w * 0.3, 210, 300)
		var top_y = maxf(56.0, head.y - 54)
		var cx = clampf(head.x, plate_w * 0.5 + 12, w - plate_w * 0.5 - 12)
		var name: String = state.enemy_name()
		var name_color = Color("ffd37a") if state.enemy_elite else (Color("ff9c7a") if state.is_boss() else Color("f1e9da"))
		if state.is_boss():
			_text_center(body, state.boss_title(), Vector2(cx, top_y - 22), 13, Color("e7b089"))
		_text_center(font, name, Vector2(cx, top_y), 22, name_color, 5)
		var bar = Rect2(cx - plate_w * 0.5, top_y + 10, plate_w, 12)
		overlay.draw_rect(bar.grow(2), Color(0.02, 0.03, 0.05, 0.85))
		var ratio = state.enemy_hp / maxf(1.0, state.enemy_max)
		overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_trail, bar.size.y)), Color(1, 0.95, 0.85, 0.55))
		var fill = Color("e0645a") if state.is_boss() else (Color("e8b450") if state.enemy_elite else Color("6fcf9f"))
		if state.echo_healing() and not reduced_motion:
			fill = fill.lerp(Color("b18cf0"), 0.5 + 0.5 * sin(ambient_time * 6.0))
		overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
		overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3)), Color(1, 1, 1, 0.25))
		var health_text = "%s / %s" % [compact_number(ceil(state.enemy_hp)), compact_number(ceil(state.enemy_max))]
		if state.echo_healing():
			health_text += "  ·  ECO: ATACA PARA DETENERLO"
		_text_center(body, health_text, Vector2(cx, bar.end.y + 17), 13, Color("c9a6f5") if state.echo_healing() else Color("c3cbd3"), 3)
		if not state.enemy_hint().is_empty() and not state.is_boss():
			_text_center(body, state.enemy_hint(), Vector2(cx, top_y - 24), 13, Color("acd5ff"), 3)
		# Telegraph.
		var feet = stage_to_screen(ENEMY_FEET)
		var tele_w = plate_w * 0.8
		var tele = Rect2(cx - tele_w * 0.5, minf(feet.y + 26, size.y - 46), tele_w, 7)
		if state.charging:
			var k = state.charge_progress()
			var pulse = 0.6 + 0.4 * sin(ambient_time * 16.0)
			tele = Rect2(w * 0.5 - w * 0.3, size.y * 0.16, w * 0.6, 12)
			overlay.draw_rect(tele.grow(3), Color(0.1, 0.02, 0.02, 0.9))
			overlay.draw_rect(Rect2(tele.position, Vector2(tele.size.x * k, tele.size.y)), Color(1, 0.35 + 0.3 * pulse, 0.1))
			var cue = " · DESTELLO [E]"
			if state.bell_silence():
				cue = " · SUELTA EL ATAQUE"
			elif state.is_forge_keeper():
				cue = " · ¡RÓMPELA!"
			_text_center(font, state.charge_name() + cue, Vector2(w * 0.5, tele.position.y - 12), 24, Color(1, 0.8 * pulse + 0.2, 0.4), 6)
			if state.bell_silence():
				_text_center(body, "Luceros seguros · Resonancia %d/3" % state.bell_resonance, Vector2(w * 0.5, tele.end.y + 22), 16, Color("c9a6f5"), 3)
			elif state.forge_armor > 0:
				var armor = Rect2(tele.position.x, tele.end.y + 8, tele.size.x * state.forge_armor / maxf(1.0, state.forge_armor_max()), 8)
				overlay.draw_rect(Rect2(tele.position.x, armor.position.y, tele.size.x, 8).grow(2), Color(0.05, 0.03, 0.02, 0.9))
				overlay.draw_rect(armor, Color("ff9a4a"))
				_text_center(body, "Coraza %s · Destello ×1,5" % compact_number(ceil(state.forge_armor)), Vector2(w * 0.5, armor.end.y + 20), 16, Color("ffc58a"), 3)
		elif state.stun_time > 0:
			_text_center(font, "ATURDIDO", Vector2(cx, tele.position.y + 18), 18, Color("ffe38a"), 4)
		elif state.spawn_delay <= 0:
			var warn = state.attack_timer / state.attack_interval()
			overlay.draw_rect(tele.grow(2), Color(0.02, 0.03, 0.05, 0.8))
			var col = Color("ff7a4a") if warn > 0.8 else Color("8e9cab")
			overlay.draw_rect(Rect2(tele.position, Vector2(tele.size.x * warn, tele.size.y)), col)
			var label = "Golpe en %.1f s" % maxf(0, state.attack_interval() - state.attack_timer)
			if state.next_is_heavy():
				label = "Canaliza en %.1f s" % maxf(0, state.attack_interval() - state.attack_timer)
			_text_center(body, label, Vector2(cx, tele.end.y + 18), 14, Color("ffb08a") if warn > 0.8 else Color("aab6c1"), 3)
	# Combo and fury near the bearer.
	var hero_top = stage_to_screen(HERO_FEET + Vector2(0, -hero.height() - 18))
	if state.combo >= 3 and not state.dead:
		var k = state.combo_time / 1.5
		var txt = "CADENA ×%d" % state.combo
		_text_center(font, txt, hero_top + Vector2(0, -12), 20 + mini(state.combo, 20) / 2, Color("ffcf7b"), 5)
		overlay.draw_rect(Rect2(hero_top + Vector2(-44, -4), Vector2(88 * k, 4)), Color("ffcf7b"))
	if state.fury_time > 0:
		_text_center(font, "FURIA %.0f s" % state.fury_time, hero_top + Vector2(0, -40), 18, Color("ff8a3d"), 4)
	# Damage numbers.
	for n in numbers:
		var p = stage_to_screen(n.pos)
		var a = clampf(n.life * 2.0, 0, 1)
		_text_center(font, n.text, p, n.size, Color(n.color, a), 6, Color(0.05, 0.03, 0.02, a))
	# First-steps hint.
	if hint_alpha > 0 and state.total_kills < 3 and state.active():
		var pulse = 0.65 + 0.35 * sin(ambient_time * 4.0)
		_text_center(font, "HAZ CLIC PARA ATACAR  ·  ESPACIO", Vector2(w * 0.5, size.y - 28), 22, Color(1, 0.85, 0.55, hint_alpha * pulse), 5)
	if state.ember_active:
		var p = stage_to_screen(ember_stage_pos())
		_text_center(body, "¡Ascua errante!", p + Vector2(0, -44), 14, Color(1, 0.88, 0.6, 0.9), 3)
	# Banner.
	if not banner.is_empty():
		var t: float = banner.t
		var a = clampf(t / 0.35, 0, 1) * clampf((banner.dur - t) / 0.6, 0, 1)
		var y = size.y * 0.24
		overlay.draw_rect(Rect2(0, y - 52, w, 92), Color(0.02, 0.02, 0.04, 0.55 * a))
		overlay.draw_rect(Rect2(0, y - 52, w, 2), Color(banner.color, 0.6 * a))
		overlay.draw_rect(Rect2(0, y + 38, w, 2), Color(banner.color, 0.6 * a))
		_text_center(font, banner.title, Vector2(w * 0.5, y), 40, Color(banner.color, a), 7)
		_text_center(body, banner.subtitle, Vector2(w * 0.5, y + 26), 16, Color(0.92, 0.9, 0.85, a), 3)

func _frame_glow(color: Color) -> void:
	var steps = 10
	for i in range(steps):
		var k = float(i) / steps
		var c = Color(color, color.a * (1.0 - k) * 0.35)
		var inset = k * 70.0
		overlay.draw_rect(Rect2(inset, inset, size.x - inset * 2, size.y - inset * 2), c, false, 8.0)

func _text_center(font: Font, text: String, pos: Vector2, font_size: int, color: Color, outline: int = 0, outline_color: Color = Color(0.03, 0.03, 0.05, 1)) -> void:
	if font == lib.heading_font:
		font_size = int(font_size * 1.22)
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at = Vector2(pos.x - width * 0.5, pos.y)
	if outline > 0:
		overlay.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(outline_color, outline_color.a * color.a))
	overlay.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func compact_number(value: float) -> String:
	if value >= 1e15:
		var exponent = floor(log(value) / log(10))
		return "%.2fe%d" % [value / pow(10, exponent), int(exponent)]
	if value >= 1e12: return "%.1fT" % (value / 1e12)
	if value >= 1e9: return "%.1fB" % (value / 1e9)
	if value >= 1e6: return "%.1fM" % (value / 1e6)
	if value >= 10000: return "%.1fk" % (value / 1000)
	if value < 10 and not is_equal_approx(value, round(value)):
		return "%.1f" % value
	return str(int(round(value)))
