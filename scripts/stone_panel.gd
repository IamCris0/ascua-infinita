extends PanelContainer
## Stone panel inspired by the Gemini interface reference: bevelled slate,
## a recessed inner field and riveted iron straps across the corners.

@export var straps: bool = true
@export var strap_size: float = 58.0
@export var inner_inset: float = 9.0
@export var accent: Color = Color(0, 0, 0, 0)

const BEVEL_LIGHT = Color("5b6271")
const BEVEL_DARK = Color("121419")
const INNER_LINE = Color("1a1d24")
const STRAP = Color("2c303b")
const STRAP_LIGHT = Color("4d5363")
const OUTLINE = Color("07080b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	# Bevel: light top-left, dark bottom-right.
	draw_line(Vector2(4, 3), Vector2(size.x - 5, 3), BEVEL_LIGHT, 2.0)
	draw_line(Vector2(3, 4), Vector2(3, size.y - 5), Color(BEVEL_LIGHT, 0.7), 2.0)
	draw_line(Vector2(4, size.y - 4), Vector2(size.x - 4, size.y - 4), BEVEL_DARK, 3.0)
	draw_line(Vector2(size.x - 4, 4), Vector2(size.x - 4, size.y - 4), BEVEL_DARK, 3.0)
	var inner = r.grow(-inner_inset)
	if inner.size.x > 20 and inner.size.y > 20:
		draw_rect(inner, Color(0, 0, 0, 0.16))
		draw_rect(inner, INNER_LINE, false, 2.0)
		draw_line(inner.position + Vector2(1, inner.size.y + 1), inner.end + Vector2(0, 1), Color(BEVEL_LIGHT, 0.35), 1.0)
	if accent.a > 0:
		draw_line(Vector2(inner_inset + 6, inner_inset + 1), Vector2(size.x - inner_inset - 6, inner_inset + 1), accent, 2.0)
	# Hairline cracks give the slate some texture without an image.
	var seed_x = int(size.x) * 7 + int(size.y) * 13
	for i in range(3):
		var x = fmod(seed_x * (i + 3) * 0.37, maxf(1.0, size.x - 80)) + 40
		var y = fmod(seed_x * (i + 5) * 0.21, maxf(1.0, size.y - 80)) + 40
		var pts = PackedVector2Array([Vector2(x, y), Vector2(x + 6, y + 9), Vector2(x + 3, y + 17), Vector2(x + 10, y + 26)])
		draw_polyline(pts, Color(0, 0, 0, 0.22), 1.0)
	if straps and size.x > strap_size * 2.4 and size.y > strap_size * 2.4:
		var s = strap_size
		_strap(Vector2(0, s), Vector2(s, 0), 1)
		_strap(Vector2(size.x - s, 0), Vector2(size.x, s), 1)
		_strap(Vector2(0, size.y - s), Vector2(s, size.y), -1)
		_strap(Vector2(size.x - s, size.y), Vector2(size.x, size.y - s), -1)

func _strap(a: Vector2, b: Vector2, _dir: int) -> void:
	var dir = (b - a).normalized()
	var n = Vector2(-dir.y, dir.x) * 8.0
	var ext = dir * 6.0
	var pts = PackedVector2Array([a - ext + n, b + ext + n, b + ext - n, a - ext - n])
	draw_colored_polygon(pts, STRAP)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUTLINE, 2.0)
	draw_line(a - ext + n * 0.6, b + ext + n * 0.6, STRAP_LIGHT, 1.5)
	for k in [0.18, 0.5, 0.82]:
		var c = a.lerp(b, k)
		draw_circle(c, 3.2, OUTLINE)
		draw_circle(c, 2.2, Color("5e6575"))
		draw_circle(c + Vector2(-0.7, -0.7), 0.9, Color("9aa2b3"))
