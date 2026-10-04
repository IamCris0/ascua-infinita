extends Control
## Coins and ascuas that fly from a defeated enemy to the HUD counters.

signal arrived(kind: String)

var items: Array = []
var gold_target: Control
var essence_target: Control
var coin_tex: Texture2D
var shard_tex: Texture2D
var reduced_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func launch(from: Vector2, coins: int, shards: int) -> void:
	if reduced_motion:
		coins = mini(coins, 3)
		shards = mini(shards, 1)
	for i in range(coins):
		_add("gold", from, i * 0.03)
	for i in range(shards):
		_add("essence", from, 0.15 + i * 0.06)

func _add(kind: String, from: Vector2, delay: float) -> void:
	var target: Control = gold_target if kind == "gold" else essence_target
	if target == null or not target.is_visible_in_tree():
		return
	var spread = Vector2(randf_range(-70, 70), randf_range(-90, -20))
	items.append({"kind": kind, "from": from, "mid": from + spread, "t": -delay, "dur": randf_range(0.55, 0.8), "target": target})

func _process(delta: float) -> void:
	if items.is_empty():
		return
	for it in items:
		it.t += delta
		if it.t >= it.dur and not it.get("done", false):
			it.done = true
			arrived.emit(it.kind)
	items = items.filter(func(it): return it.t < it.dur)
	queue_redraw()

func _draw() -> void:
	for it in items:
		if it.t < 0:
			continue
		var k = ease(clampf(it.t / it.dur, 0, 1), 0.6)
		var target: Control = it.target
		var to = target.global_position + target.size * Vector2(0.12, 0.5)
		var a = it.from.lerp(it.mid, k)
		var b = it.mid.lerp(to, k)
		var p = a.lerp(b, k)
		var tex = coin_tex if it.kind == "gold" else shard_tex
		var s = 22.0 if it.kind == "gold" else 26.0
		if tex:
			draw_texture_rect(tex, Rect2(p - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
		else:
			draw_circle(p, 6, Color("f0c27a"))
