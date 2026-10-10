extends Control
## Opening a chest: knock the lock a few times, the lid flies open in a burst
## of light and the rewards rise out one by one. The rules roll the loot the
## moment it opens (`open_loot` returns it); this only shows it.

signal finished

const KNOCKS = 3
const REVEAL_STEP = 0.42
const TIER_COLORS = [Color("ffb070"), Color("ffe7a8"), Color("7fe0bf")]

var lib
var audio
var tier: int = 0
var open_loot: Callable
var icon_for: Callable
var text_for: Callable
var reduced_motion: bool = false
var knocks: int = 0
var knock_time: float = 9.0
var opened_at: float = -1.0
var time: float = 0.0
var loot: Array = []
var revealed: int = 0
var done: bool = false
var sparks: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(660, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		knock()
		accept_event()

func is_open() -> bool:
	return opened_at >= 0

## One blow on the lock; the last one opens the chest.
func knock() -> void:
	if is_open():
		return
	knocks += 1
	knock_time = 0.0
	if knocks < (1 if reduced_motion else KNOCKS):
		audio.play("chest_hit", 0.08)
		_burst(chest_center() + Vector2(0, 10), [Color("ffe7a8"), Color("ff9a4a")], 8, 160.0)
		return
	loot = open_loot.call()
	opened_at = time
	var rare = tier == 2 or loot.any(func(entry): return entry.kind == "relic")
	audio.play("chest_rare" if rare else "chest_open")
	_burst(chest_center() + Vector2(0, -30), [TIER_COLORS[tier], Color("fff1cf"), Color("ffcf7b")], 46, 420.0)
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func chest_center() -> Vector2:
	return Vector2(size.x * 0.5, 150)

func _burst(at: Vector2, palette: Array, count: int, power: float) -> void:
	if reduced_motion:
		count = int(count / 3.0)
	for i in range(count):
		var angle = randf_range(-PI, 0.0)
		sparks.append({"pos": at, "vel": Vector2(cos(angle), sin(angle)) * randf_range(power * 0.3, power), "life": randf_range(0.5, 1.1), "color": palette[randi() % palette.size()], "size": randf_range(3, 6)})

func _process(delta: float) -> void:
	time += delta
	knock_time += delta
	for s in sparks:
		s.life -= delta
		s.pos += s.vel * delta
		s.vel.y += 520 * delta
	sparks = sparks.filter(func(s): return s.life > 0)
	if is_open() and not done:
		var due = int((time - opened_at - 0.35) / REVEAL_STEP) + 1
		while revealed < mini(due, loot.size()):
			revealed += 1
			audio.play("loot", 0.06)
		if revealed >= loot.size() and time - opened_at > 0.35 + REVEAL_STEP * loot.size():
			done = true
			finished.emit()
	queue_redraw()

func _draw() -> void:
	var c = chest_center()
	var glow = TIER_COLORS[tier]
	var open_k = clampf((time - opened_at) / 0.4, 0, 1) if is_open() else 0.0
	# Halo, and the rays of an opened chest.
	for i in range(6):
		var r = 150.0 - i * 20 + 40 * open_k
		draw_circle(c, r, Color(glow, (0.035 + 0.03 * open_k) * (1.0 if not reduced_motion else 0.6)))
	if is_open():
		var spin = 0.0 if reduced_motion else time * 0.35
		for i in range(10):
			var a = spin + i * TAU / 10.0
			var tip = c + Vector2(cos(a), sin(a)) * 230 * open_k
			var side = Vector2(cos(a + 0.09), sin(a + 0.09)) * 230 * open_k + c
			draw_colored_polygon(PackedVector2Array([c, tip, side]), Color(glow, 0.12))
	var shake = 0.0
	if knock_time < 0.3 and not reduced_motion:
		shake = sin(knock_time * 70.0) * 7.0 * (1.0 - knock_time / 0.3)
	var lift = 0.0 if reduced_motion or is_open() else sin(time * 2.4) * 3.0
	var art: Texture2D = lib.chest_art(tier, is_open())
	var scale = 1.5
	var size_px = Vector2(art.get_width(), art.get_height()) * scale
	draw_texture_rect(art, Rect2(c - size_px * 0.5 + Vector2(shake, lift), size_px), false)
	# The lock glows a little more with each knock.
	if not is_open() and knocks > 0:
		var lock = c + Vector2(shake, lift + 4)
		draw_circle(lock, 10 + knocks * 4, Color(1, 0.85, 0.5, 0.18 * knocks))
	for s in sparks:
		draw_rect(Rect2(s.pos - Vector2.ONE * s.size * 0.5, Vector2.ONE * s.size), Color(s.color, clampf(s.life / 0.4, 0, 1)))
	var font: Font = lib.heading_font
	var body: Font = ThemeDB.fallback_font
	if not is_open():
		var left = (1 if reduced_motion else KNOCKS) - knocks
		var hint = "HAZ CLIC PARA ABRIRLO" if left == 1 else "GOLPEA EL CERROJO  ·  %d" % left
		var pulse = 0.7 + 0.3 * sin(time * 4.0)
		_text(font, hint, Vector2(size.x * 0.5, 300), 22, Color(1, 0.88, 0.6, pulse))
		_text(body, "Clic o Espacio", Vector2(size.x * 0.5, 324), 13, Color(0.7, 0.72, 0.78))
		return
	# Reward cards rise out of the chest one after another.
	var count = loot.size()
	var card_w = 200.0
	var gap = 14.0
	var total = count * card_w + (count - 1) * gap
	for i in range(revealed):
		var appear = clampf((time - opened_at - 0.35 - i * REVEAL_STEP) / 0.3, 0, 1)
		var k = ease(appear, 0.4)
		var x = size.x * 0.5 - total * 0.5 + i * (card_w + gap)
		var y = lerpf(190.0, 290.0, k)
		var rect = Rect2(x, y, card_w, 76)
		draw_rect(rect, Color(0.08, 0.08, 0.11, 0.95 * k))
		draw_rect(rect, Color(glow, 0.9 * k), false, 2.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color(glow, 0.9 * k))
		var icon: Texture2D = icon_for.call(loot[i])
		if icon:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(10, 14), Vector2(48, 48)), false, Color(1, 1, 1, k))
		_text_left(body, text_for.call(loot[i]), rect.position + Vector2(64, 44), 14, Color(0.95, 0.92, 0.85, k), card_w - 70)

func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	text = tr(text)
	if font == lib.heading_font:
		font_size = int(font_size * 1.22)
	var at = Vector2(pos.x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, pos.y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.03, 0.02, 0.02, color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _text_left(font: Font, text: String, pos: Vector2, font_size: int, color: Color, width: float) -> void:
	draw_string(font, pos, tr(text), HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
