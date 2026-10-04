extends Control
## Animated backdrop for the title screen and the bonfire: a Gemini background,
## the bearer breathing by a fire and drifting embers.

const Actor = preload("res://scripts/actor.gd")

var lib
var background: int = 0
var hero
var companions: int = 3
var time: float = 0.0
var embers: Array = []
var glow: Texture2D
var shade: Texture2D
var hero_anchor: Vector2 = Vector2(0.68, 0.86)
var hero_scale: float = 1.7
var campfire: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lib = load("res://scripts/art_library.gd").shared()
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	glow = gt
	var sg = Gradient.new()
	sg.set_color(0, Color(0.02, 0.025, 0.04, 0.9))
	sg.set_color(1, Color(0.02, 0.025, 0.04, 0.0))
	sg.add_point(0.45, Color(0.02, 0.025, 0.04, 0.55))
	var st = GradientTexture2D.new()
	st.gradient = sg
	st.width = 256
	st.height = 4
	shade = st
	hero = Actor.new(lib, "hero")
	add_child(hero)
	for i in range(46):
		embers.append(_ember(true))

func _ember(anywhere: bool) -> Dictionary:
	return {"pos": Vector2(randf(), randf() if anywhere else 1.05), "speed": randf_range(0.02, 0.07), "phase": randf() * TAU,
		"size": randf_range(2, 5), "hue": randf()}

func _process(delta: float) -> void:
	hero.speed = 0.0 if reduced_motion else 1.0
	if not reduced_motion:
		time += delta
		for e in embers:
			e.pos.y -= e.speed * delta
			e.pos.x += sin(time * 0.8 + e.phase) * 0.006 * delta
		for i in range(embers.size()):
			if embers[i].pos.y < -0.05:
				embers[i] = _ember(false)
	var s = _cover_scale()
	hero.position = size * hero_anchor
	hero.base_scale = hero_scale * s
	queue_redraw()

func _cover_scale() -> float:
	return maxf(size.x / 1024.0, size.y / 800.0)

func _draw() -> void:
	var tex: Texture2D = lib.backgrounds[background]
	var s = _cover_scale()
	var drawn = Vector2(1024, 800) * s
	draw_texture_rect(tex, Rect2((size - drawn) * Vector2(0.5, 0.75), drawn), false)
	# Darken toward the left where the menu sits, and the bottom edge.
	draw_texture_rect(shade, Rect2(0, 0, size.x * 0.75, size.y), false)
	var feet = size * hero_anchor
	if campfire:
		var fire = feet + Vector2(-150 * s, 0)
		var r = 260.0 * s * (1.0 + 0.06 * sin(time * 9.0) + 0.04 * sin(time * 21.0))
		draw_texture_rect(glow, Rect2(fire - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(1, 0.55, 0.2, 0.45))
		lib.draw_fx(self, "embers", fmod(time, 0.3), fire + Vector2(0, -40 * s), 170 * s, Color(1, 1, 1), 13.0)
		for i in range(5):
			var x = fire.x + (i - 2) * 16 * s
			draw_rect(Rect2(x - 14 * s, fire.y - 6 * s, 28 * s, 9 * s), Color("3b2a22"))
		lib.draw_fx(self, "critical", fmod(time * 0.5, 0.28), fire + Vector2(0, -22 * s), 90 * s, Color(1, 0.8, 0.5, 0.8), 14.0, time)
	else:
		var r = 220.0 * s
		draw_texture_rect(glow, Rect2(feet + Vector2(0, -90 * s) - Vector2.ONE * r, Vector2.ONE * r * 2), false, Color(0.4, 0.9, 0.75, 0.16))
	for i in range(companions):
		var a = time * 1.4 + i * TAU / maxf(1, companions)
		var pos = feet + Vector2(cos(a) * 110 * s, -150 * s + sin(a) * 34 * s)
		lib.draw_frame(self, "companion", lib.frame_at("companion", "idle", time + i * 0.3), pos, s * 1.6)
	for e in embers:
		var c = Color(1.0, 0.55 + 0.3 * e.hue, 0.25, 0.75 * (0.5 + 0.5 * sin(time * 3.0 + e.phase)))
		draw_rect(Rect2(e.pos * size, Vector2.ONE * e.size), c)
