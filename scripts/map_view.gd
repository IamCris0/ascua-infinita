extends Control
## The map of the next stretch: three lanes of four chambers between the
## milestone just cleared and the shared milestone or boss that follows.
## Drawn by hand. Clicking a lane chooses it; in read-only mode it shows the
## chosen lane and where the bearer is.

signal lane_chosen(index: int)

const LANE_COLORS = [Color("7fe0bf"), Color("ec8a6d"), Color("b18cf0")]
const NODE_COLORS = {"fight": Color("aab6c1"), "elite": Color("e0645a"), "rest": Color("6fcf7e"), "chest": Color("f2c47c"),
	"shrine": Color("ffb070"), "merchant": Color("e8bd75"), "altar": Color("b18cf0"), "wheel": Color("f2c47c")}
# Lane rows as a share of the height.
const ROWS = [0.2, 0.46, 0.72]
const NODE_RADIUS = 30.0

var state
var lib
var read_only: bool = false
var reduced_motion: bool = false
var hovered_lane: int = -1
var hovered_node: Vector2i = Vector2i(-1, -1)
var time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(1040, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func():
		hovered_node = Vector2i(-1, -1)
		if not read_only:
			hovered_lane = -1
	)

func _process(delta: float) -> void:
	if not reduced_motion:
		time += delta
	queue_redraw()

func start_pos() -> Vector2:
	return Vector2(74, size.y * ROWS[1])

func end_pos() -> Vector2:
	return Vector2(size.x - 84, size.y * ROWS[1])

func node_pos(lane_index: int, k: int) -> Vector2:
	var x = lerpf(250.0, size.x - 270.0, k / float(state.LANE_LENGTH - 1))
	return Vector2(x, size.y * ROWS[lane_index])

func node_under(p: Vector2) -> Vector2i:
	for i in range(state.lanes.size()):
		for k in range(state.LANE_LENGTH):
			if p.distance_to(node_pos(i, k)) <= NODE_RADIUS + 6:
				return Vector2i(i, k)
	return Vector2i(-1, -1)

func lane_under(p: Vector2) -> int:
	var hit = node_under(p)
	if hit.x >= 0:
		return hit.x
	for i in range(state.lanes.size()):
		if absf(p.y - size.y * ROWS[i]) < 42 and p.x > 190 and p.x < size.x - 200:
			return i
	return -1

func _gui_input(e: InputEvent) -> void:
	if state == null or state.lanes.is_empty():
		return
	if e is InputEventMouseMotion:
		hovered_node = node_under(e.position)
		if not read_only:
			hovered_lane = lane_under(e.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not read_only and hovered_lane >= 0 else Control.CURSOR_ARROW
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not read_only:
		var i = lane_under(e.position)
		if i >= 0:
			lane_chosen.emit(i)
			accept_event()

## How strongly a lane is drawn: the hovered or chosen one stands out.
func lane_alpha(i: int) -> float:
	if read_only:
		return 1.0 if i == state.lane else 0.3
	return 1.0 if hovered_lane < 0 or hovered_lane == i else 0.35

func _draw() -> void:
	if state == null or state.lanes.is_empty():
		return
	var font: Font = lib.heading_font
	var body: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.05, 0.075, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.22, 0.3, 0.6), false, 2.0)
	for i in range(46):
		var p = Vector2(fmod(i * 97.31 + 13.0, size.x), fmod(i * 53.77 + 29.0, size.y))
		draw_circle(p, 1.3, Color(1, 0.95, 0.85, 0.06 + 0.05 * sin(time * 1.7 + i)))
	for i in range(state.lanes.size()):
		var a = lane_alpha(i)
		var color = Color(LANE_COLORS[i], a)
		var strong = (read_only and i == state.lane) or (not read_only and hovered_lane == i)
		var points: Array = [start_pos()]
		for k in range(state.LANE_LENGTH):
			points.append(node_pos(i, k))
		points.append(end_pos())
		for j in range(points.size() - 1):
			_dashed(points[j], points[j + 1], color, 4.0 if strong else 2.5)
		var label_at = node_pos(i, 0) + Vector2(-NODE_RADIUS, -NODE_RADIUS - 12)
		var title = "%d · %s" % [i + 1, state.LANES[i].name.to_upper()] if not read_only else state.LANES[i].name.to_upper()
		_text(font, title, label_at, 19, color, false)
		var title_width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * 1.22)).x
		_text(body, state.LANES[i].hint, label_at + Vector2(title_width + 14, -1), 13, Color(0.82, 0.8, 0.86, a), false)
	for i in range(state.lanes.size()):
		for k in range(state.LANE_LENGTH):
			_draw_node(i, k, body)
	_draw_ends(font, body)
	# Chamber numbers, and the special rivals that wait there on every lane.
	for k in range(state.LANE_LENGTH):
		var chamber = state.lane_start + k
		var role = "Guardián del Umbral" if chamber % 10 == 6 else ("Acólito del Eco" if chamber % 10 == 8 else "")
		_text(body, "Cámara %d" % chamber, Vector2(node_pos(0, k).x, size.y - (24 if not role.is_empty() else 8)), 12, Color(0.6, 0.62, 0.68), true)
		if not role.is_empty():
			_text(body, role, Vector2(node_pos(0, k).x, size.y - 8), 12, Color(0.72, 0.82, 1.0), true)
	_draw_tooltip(font, body)

func _draw_node(i: int, k: int, body: Font) -> void:
	var kind: String = state.lanes[i][k]
	var p = node_pos(i, k)
	var chamber = state.lane_start + k
	var a = lane_alpha(i)
	var on_lane = read_only and i == state.lane
	var done = on_lane and chamber < state.room
	var here = on_lane and chamber == state.room
	var r = NODE_RADIUS * (1.12 if hovered_node == Vector2i(i, k) else 1.0)
	var color: Color = NODE_COLORS.get(kind, Color.WHITE)
	draw_circle(p + Vector2(0, 3), r + 3, Color(0, 0, 0, 0.55 * a))
	draw_circle(p, r, Color(0.09, 0.09, 0.12, a))
	draw_arc(p, r, 0, TAU, 40, Color(color, a * (0.5 if done else 1.0)), 3.0)
	if here:
		var pulse = 0.5 + 0.5 * sin(time * 5.0)
		draw_arc(p, r + 6 + pulse * 4, 0, TAU, 40, Color(1, 0.9, 0.6, 0.8), 2.5)
	draw_texture_rect(lib.map_icon(kind), Rect2(p - Vector2.ONE * 22, Vector2.ONE * 44), false, Color(1, 1, 1, a * (0.4 if done else 1.0)))

func _draw_ends(font: Font, body: Font) -> void:
	var s = start_pos()
	draw_circle(s, 38, Color(0.09, 0.09, 0.12))
	draw_arc(s, 38, 0, TAU, 48, Color("f2c47c"), 3.0)
	if lib.characters.hero.has("portrait"):
		draw_texture_rect(lib.portrait("hero"), Rect2(s - Vector2.ONE * 28, Vector2.ONE * 56), false)
	_text(body, "Cámara %d" % (state.lane_start - 1) if state.lane_start > 1 else "Inicio", s + Vector2(0, 56), 12, Color(0.75, 0.75, 0.8), true)
	var e = end_pos()
	var chamber = state.lane_start + state.LANE_LENGTH
	var boss = chamber % 10 == 0
	var color = Color("e0645a") if boss else Color("f2c47c")
	var pulse = 0.5 + 0.5 * sin(time * 3.0)
	draw_circle(e, 40, Color(0.09, 0.09, 0.12))
	draw_arc(e, 40 + pulse * 3, 0, TAU, 48, color, 3.0)
	draw_texture_rect(lib.map_icon("boss" if boss else "milestone"), Rect2(e - Vector2.ONE * 26, Vector2.ONE * 52), false)
	_text(font, "JEFE" if boss else "RELIQUIA", e + Vector2(0, 62), 17, color, true)
	_text(body, "Cámara %d" % chamber, e + Vector2(0, 80), 12, Color(0.75, 0.75, 0.8), true)

func _draw_tooltip(font: Font, body: Font) -> void:
	if hovered_node.x < 0:
		return
	var kind: String = state.lanes[hovered_node.x][hovered_node.y]
	var p = node_pos(hovered_node.x, hovered_node.y)
	var title = "%s · cámara %d" % [state.NODES[kind].name, state.lane_start + hovered_node.y]
	var hint: String = state.NODES[kind].hint
	var width = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * 1.22)).x, body.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 28
	var box = Rect2(p + Vector2(-width * 0.5, NODE_RADIUS + 12), Vector2(width, 58))
	if box.end.y > size.y - 4:
		box.position.y = p.y - NODE_RADIUS - 12 - box.size.y
	box.position.x = clampf(box.position.x, 4, size.x - width - 4)
	draw_rect(box, Color(0.06, 0.06, 0.09, 0.96))
	draw_rect(box, Color(NODE_COLORS.get(kind, Color.WHITE), 0.8), false, 2.0)
	_text(font, title, box.position + Vector2(14, 24), 17, Color("f2e6cf"), false)
	_text(body, hint, box.position + Vector2(14, 46), 14, Color(0.84, 0.84, 0.88), false)

## A dashed path whose dashes drift toward the destination.
func _dashed(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var length = a.distance_to(b)
	if length <= 0:
		return
	var dir = (b - a) / length
	var t = -fmod(time * 26.0, 20.0)
	while t < length:
		var s0 = maxf(t, 0)
		var s1 = minf(t + 12.0, length)
		if s1 > s0:
			draw_line(a + dir * s0, a + dir * s1, color, width)
		t += 20.0

func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, center: bool) -> void:
	if font == lib.heading_font:
		font_size = int(font_size * 1.22)
	var at = pos
	if center:
		at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02, 0.02, 0.04, color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
