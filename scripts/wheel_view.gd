extends Control
## La Rueda del eclipse: ten equal sectors under a pointer. The rules decide
## the sector when the bet is paid; `spin` only animates the wheel onto it,
## ticking on every peg and slowing to a stop.

signal finished(index: int)

const SECTOR_COLORS = {"nothing": Color("2b2f3a"), "gold2": Color("b8862f"), "gold3": Color("f2c47c"), "heal": Color("4f9f63"),
	"relic": Color("7d5bc4"), "chest": Color("8a5a2b"), "essence": Color("2f8f74")}
const SPIN_TIME = 3.6
const TURNS = 5

var lib
var audio
var sectors: Array = []
var names: Dictionary = {}
var icon_for: Callable
var reduced_motion: bool = false
var angle: float = 0.0
var spin_from: float = 0.0
var spin_to: float = 0.0
var spin_time: float = -1.0
var duration: float = SPIN_TIME
var result: int = -1
var last_peg: int = 0
var pointer_kick: float = 0.0
var flash: float = 0.0
var time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(440, 440)

func radius() -> float:
	return minf(size.x, size.y) * 0.5 - 24.0

func center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 10)

func step() -> float:
	return TAU / sectors.size()

func spinning() -> bool:
	return spin_time >= 0

## Turns the wheel so the pointer stops inside sector `index`.
func spin(index: int) -> void:
	result = index
	var jitter = randf_range(-0.32, 0.32) * step()
	var target = -(index + 0.5) * step() + jitter
	var turns = 1 if reduced_motion else TURNS
	duration = 1.4 if reduced_motion else SPIN_TIME
	spin_from = angle
	spin_to = angle + TAU * turns + fposmod(target - angle, TAU)
	spin_time = 0.0
	last_peg = int(floor(angle / step()))

## Sector under the pointer at the top.
func sector_at_pointer() -> int:
	return int(floor(fposmod(-angle, TAU) / step())) % sectors.size()

func _process(delta: float) -> void:
	time += delta
	pointer_kick = maxf(0.0, pointer_kick - delta * 6.0)
	flash = maxf(0.0, flash - delta * 0.8)
	if spinning():
		spin_time += delta
		var k = clampf(spin_time / duration, 0, 1)
		angle = lerpf(spin_from, spin_to, 1.0 - pow(1.0 - k, 3.0))
		var peg = int(floor(angle / step()))
		if peg != last_peg:
			last_peg = peg
			pointer_kick = 1.0
			audio.play("wheel_tick", 0.1)
		if k >= 1.0:
			spin_time = -1.0
			flash = 1.0
			audio.play("wheel_lose" if sectors[result] == "nothing" else "wheel_win")
			finished.emit(result)
	queue_redraw()

func _draw() -> void:
	if sectors.is_empty():
		return
	var c = center()
	var r = radius()
	var body: Font = ThemeDB.fallback_font
	draw_circle(c, r + 18, Color(0.05, 0.04, 0.06))
	draw_circle(c, r + 12, Color("5a3517"))
	draw_arc(c, r + 12, 0, TAU, 64, Color("b8862f"), 3.0)
	for i in range(sectors.size()):
		var a0 = angle + i * step() - PI / 2
		var a1 = a0 + step()
		var color: Color = SECTOR_COLORS.get(sectors[i], Color.GRAY)
		if i % 2 == 1:
			color = color.darkened(0.12)
		if flash > 0 and i == result:
			color = color.lerp(Color.WHITE, flash * (0.5 + 0.5 * sin(time * 20.0)))
		var points = PackedVector2Array([c])
		for j in range(13):
			var a = lerpf(a0, a1, j / 12.0)
			points.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, color)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color(0.05, 0.04, 0.05), 3.0)
		var mid = (a0 + a1) * 0.5
		var icon: Texture2D = icon_for.call(sectors[i])
		var at = c + Vector2(cos(mid), sin(mid)) * r * 0.66
		if icon:
			draw_texture_rect(icon, Rect2(at - Vector2(19, 26), Vector2(38, 38)), false)
		var label: String = tr(names.get(sectors[i], ""))
		var w = body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string_outline(body, at + Vector2(-w * 0.5, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(body, at + Vector2(-w * 0.5, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.97, 0.9))
		# Peg on the rim between sectors.
		draw_circle(c + Vector2(cos(a0), sin(a0)) * (r + 6), 4.0, Color("ffe7a8"))
	draw_circle(c, 34, Color("1b1424"))
	draw_arc(c, 34, 0, TAU, 40, Color("b8862f"), 3.0)
	draw_texture_rect(lib.map_icon("milestone"), Rect2(c - Vector2.ONE * 22, Vector2.ONE * 44), false)
	# Pointer at the top; each peg kicks it aside.
	var tip = c + Vector2(0, -r + 6)
	var kick = pointer_kick * 0.35
	var base = c + Vector2(0, -r - 30)
	var left = base + Vector2(-16, 0).rotated(kick)
	var right = base + Vector2(16, 0).rotated(kick)
	var tip_rotated = base + (tip - base).rotated(kick)
	draw_colored_polygon(PackedVector2Array([left, right, tip_rotated]), Color("f2c47c"))
	draw_polyline(PackedVector2Array([left, right, tip_rotated, left]), Color(0.1, 0.05, 0.02), 3.0)
