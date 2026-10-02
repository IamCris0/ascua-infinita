extends Control
## A low-resolution, original pixel stage rendered at integer coordinates.
signal clicked
var state
var time: float = 0
var hit_time: float = 0
var spawn_time: float = 0
var shake: float = 0
var particles: Array = []
var numbers: Array = []
var textures: Dictionary = {}
var hovered: bool = false
var font: Font
const BG = Color("101723")

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font = ThemeDB.fallback_font
	for key in ["hero", "slime", "wisp", "sentinel", "boss"]:
		textures[key] = load("res://assets/sprites/" + key + ".svg")
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
	)

func impact(damage: float, critical: bool, automatic: bool) -> void:
	hit_time = 0.25
	shake = 5.0 if critical else 2.0
	numbers.append({"pos": Vector2(466 + randf_range(-35, 35), 270), "life": 1.0, "text": ("¡" if critical else "") + compact_number(damage), "color": Color("ffcf7b") if critical else (Color("86e0bd") if automatic else Color("f2e9d6"))})
	for i in range(10 if critical else 5):
		particles.append({"pos": Vector2(491, 328), "vel": Vector2(randf_range(-120, 120), randf_range(-140, 30)), "life": randf_range(0.25, 0.65), "color": Color("ffcf7b") if critical else Color("86e0bd")})

func _process(delta: float) -> void:
	if state == null:
		return
	if state.active():
		time += delta
	hit_time = maxf(0, hit_time - delta)
	spawn_time = maxf(0, spawn_time - delta)
	shake = maxf(0, shake - delta * 24)
	for p in particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel.y += delta * 240
	particles = particles.filter(func(p): return p.life > 0)
	for n in numbers:
		n.life -= delta
		n.pos.y -= delta * 42
	numbers = numbers.filter(func(n): return n.life > 0)
	queue_redraw()

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(floor(x), floor(y), w, h), color)

func text_at(pos: Vector2, value: String, size_px: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	if state == null or textures.is_empty():
		return
	var scale_factor = size / Vector2(760, 590)
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	var biome: int = state.biome()
	var accent: Color = [Color("65b7a4"), Color("b79bd8"), Color("e99868")][biome]
	var stone: Color = [Color("26333b"), Color("303044"), Color("3c3033")][biome]
	box(0, 0, 760, 590, BG)
	box(0, 0, 760, 388, Color("151e2b"))
	# Stars, ruined arcade, and deep forest silhouettes.
	for i in range(38):
		var x = fmod(i * 127.0 + 49, 752)
		var y = fmod(i * 61.0 + 7, 215)
		box(x, y, 2, 2, Color(accent, 0.12 + 0.12 * sin(time + i)))
	box(340, 44, 82, 82, Color("263441"))
	box(350, 54, 62, 62, Color("394652"))
	box(369, 54, 43, 44, Color("151e2b"))
	for i in range(7):
		var x = i * 125 - 18
		box(x, 141, 49, 252, Color("1c2732"))
		box(x - 8, 140, 65, 15, stone.darkened(0.24))
		box(x + 8, 158, 7, 220, stone.darkened(0.3))
		box(x - 5, 375, 60, 17, stone)
		box(x + 50, 150, 71, 15, stone.darkened(0.4))
		box(x + 57, 165, 55, 10, stone.darkened(0.4))
	# Moss/crystals are deterministic and do not change with redraw.
	for i in range(23):
		var x = fmod(i * 93.0 + 7, 760)
		var y = 180 + fmod(i * 63.0, 192)
		box(x, y, 8, 16 + i % 4 * 7, accent.darkened(0.67))
		box(x + 8, y + 9, 6, 9, accent.darkened(0.54))
	box(0, 395, 760, 195, Color("17212b"))
	box(0, 395, 760, 5, stone.lightened(0.08))
	for row in range(5):
		for col in range(10):
			var x = col * 88 - (42 if row % 2 == 0 else 0)
			var y = 404 + row * 37
			box(x, y, 82, 31, stone.darkened(0.36 + fmod(col * 0.13, 0.2)))
			box(x + 4, y + 3, 69, 2, Color("35414a"))
	# Raised ritual dais.
	box(350, 421, 299, 17, Color("101720"))
	box(329, 400, 332, 19, stone.lightened(0.09))
	box(344, 389, 304, 14, stone.lightened(0.18))
	box(357, 390, 278, 2, accent.darkened(0.25))
	for x in [65, 682]:
		box(x, 323, 13, 77, Color("303341"))
		box(x - 8, 316, 29, 11, Color("63606a"))
		var flicker = 3 * sin(time * 10 + x)
		box(x - 2, 289 + flicker, 17, 25 - flicker, Color("ed8650"))
		box(x + 2, 281 + flicker, 8, 31 - flicker, Color("ffcf7b"))
		box(x + 4, 300, 5, 15, Color("fff1cf"))
	# Ground shadows.
	draw_ellipse_pixels(Vector2(204, 402), Vector2(54, 9), Color("0e1520"))
	draw_ellipse_pixels(Vector2(495, 400), Vector2(75, 12), Color("111722"))
	var idle = int(time * 5) % 4 if not state.reduced_motion else 0
	var hero_frame = (9 if hit_time > 0.12 else 10) if hit_time > 0 else idle
	if spawn_time > 0 and not state.reduced_motion:
		hero_frame = 4 + int(time * 12) % 4
	if state.dead:
		hero_frame = 14
	var hero_pos = Vector2(132 + (15 if hit_time > 0 else 0), 272)
	draw_texture_rect_region(textures.hero, Rect2(hero_pos, Vector2(136, 136)), Rect2(hero_frame * 32, 0, 32, 32))
	var enemy_frame = 12 if hit_time > 0.12 else idle
	if state.attack_timer / state.attack_interval() > 0.80 and hit_time <= 0:
		enemy_frame = 8 + int(time * 8) % 4
	var enemy_size = 192 if state.is_boss() else 152
	var offset = Vector2(sin(time * 71) * shake, 0) if not state.reduced_motion else Vector2.ZERO
	var enemy_pos = Vector2(494 - enemy_size / 2.0, 405 - enemy_size) + offset
	draw_texture_rect_region(textures[state.enemy_kind()], Rect2(enemy_pos, Vector2.ONE * enemy_size), Rect2(enemy_frame * 32, 0, 32, 32))
	# Orbiting companions and strike arc.
	for i in range(mini(state.wisps, 6)):
		var pos = Vector2(202 + cos(time * 1.8 + i * 1.2) * 51, 289 + sin(time * 1.8 + i * 1.2) * 18)
		box(pos.x, pos.y, 8, 8, Color("86e0bd"))
		box(pos.x + 2, pos.y + 2, 4, 4, Color("e9e9ce"))
	if hit_time > 0 and not state.reduced_motion:
		draw_arc(Vector2(410, 320), 70, -1.1, 1.1, 12, Color("fff1cf", hit_time * 3), 5)
		draw_line(Vector2(273, 325), Vector2(451, 312), Color("ffcf7b", hit_time * 2), 3)
	for p in particles:
		box(p.pos.x, p.pos.y, 4, 4, Color(p.color, minf(1, p.life * 3)))
	for n in numbers:
		text_at(n.pos, n.text, 26, Color(n.color, minf(1, n.life * 2)))
	# Enemy card / visible telegraph.
	text_at(Vector2(30, 40), "CÁMARA %02d" % state.room, 17, accent)
	text_at(Vector2(30, 69), "Un paso más hacia el corazón del eclipse.", 15, Color("8d9ba9"))
	var label = state.enemy_name()
	var name_width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	text_at(Vector2(494 - name_width / 2, 170), label, 21, Color("eae2d2"))
	box(375, 186, 238, 8, Color("090f19"))
	box(375, 186, maxf(0, 238 * state.enemy_hp / state.enemy_max), 8, Color("d87974") if state.is_boss() else accent)
	text_at(Vector2(420, 217), "%s / %s" % [compact_number(ceil(state.enemy_hp)), compact_number(ceil(state.enemy_max))], 15, Color("9baab7"))
	var warning: float = state.attack_timer / state.attack_interval()
	box(402, 441, 187, 4, Color("0d141e"))
	box(402, 441, 187 * warning, 4, Color("ed8650") if warning > 0.8 else Color("64717e"))
	text_at(Vector2(407, 468), "Golpe en %.1f s" % maxf(0, state.attack_interval() - state.attack_timer), 15, Color("edaa85") if warning > 0.8 else Color("8999a8"))
	var prompt = "CLIC PARA ATACAR   /   ESPACIO"
	var prompt_width = font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	text_at(Vector2((760 - prompt_width) / 2, 539), prompt, 18, Color("ffcf7b") if hovered else Color("a5b2bc"))
	if state.combo >= 4:
		text_at(Vector2(166, 446), "CADENA ×%d" % state.combo, 16, Color("ffcf7b"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_pixels(center: Vector2, radius: Vector2, color: Color) -> void:
	for y in range(-int(radius.y), int(radius.y), 3):
		var width = radius.x * sqrt(maxf(0, 1 - pow(y / radius.y, 2)))
		box(center.x - width, center.y + y, width * 2, 3, color)

func compact_number(value: float) -> String:
	if value >= 1e12:
		var exponent = floor(log(value) / log(10))
		return "%.1fe%d" % [value / pow(10, exponent), int(exponent)]
	if value >= 1e9: return "%.1fB" % (value / 1e9)
	if value >= 1e6: return "%.1fM" % (value / 1e6)
	if value >= 10000: return "%.1fk" % (value / 1000)
	return str(int(value))
