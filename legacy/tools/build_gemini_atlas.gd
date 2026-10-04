extends SceneTree
## Builds native SpriteFrames/AtlasTexture resources without rewriting raster pixels.
## All regions below use the proportions of the user-supplied sheets.
const ROOT = "res://assets/gemini/"
var failures: int = 0

func row(columns: Array, y: float, h: float, count: int = 8) -> Array:
	var result: Array = []
	for x in columns:
		result.append(Rect2(float(x) / count, y, 1.0 / count, h))
	return result

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "animations")
	build_character("hero", {
		"idle": row([0, 1, 2, 3], 0, 0.25),
		"walk": row([0, 1, 2, 3, 4, 5, 6, 7], 0.25, 0.25),
		"attack": row([0, 1, 2, 3, 4, 5, 6], 0.50, 0.25),
		"hurt": row([0, 1], 0.75, 0.25),
		"death": row([2, 3, 4], 0.75, 0.25)
	})
	build_character("slime", {
		"idle": row([0, 1, 2, 3], 0, 0.25),
		"walk": row([0, 3, 4, 5, 7], 0.25, 0.25),
		"attack": [Rect2(0, 0.5, 0.18, 0.25), Rect2(0.28, 0.5, 0.19, 0.25), Rect2(0.51, 0.5, 0.16, 0.25), Rect2(0.68, 0.5, 0.16, 0.25), Rect2(0.85, 0.5, 0.15, 0.25)],
		"hurt": [Rect2(0, 0.75, 0.16, 0.25), Rect2(0.18, 0.75, 0.17, 0.25)],
		"death": [Rect2(0.36, 0.75, 0.14, 0.25), Rect2(0.51, 0.75, 0.16, 0.25), Rect2(0.68, 0.75, 0.18, 0.25)]
	}, false)
	build_character("wisp", {
		"idle": row([0, 1, 2, 3], 0, 0.25),
		"walk": row([4, 5, 6, 7], 0, 0.25),
		"attack": row([3, 4, 5, 6, 7], 0.25, 0.25),
		"hurt": row([3, 4], 0.50, 0.25),
		"death": row([5, 6, 7], 0.50, 0.25)
	}, false)
	build_character("sentinel", {
		"idle": row([0, 1, 2, 3], 0, 0.28),
		"walk": row([4, 5, 6, 7], 0, 0.28),
		"attack": [Rect2(0, 0.31, 0.19, 0.42), Rect2(0.20, 0.31, 0.30, 0.42), Rect2(0.51, 0.31, 0.23, 0.42), Rect2(0.75, 0.31, 0.25, 0.42)],
		"hurt": [Rect2(0, 0.74, 0.17, 0.26), Rect2(0.18, 0.74, 0.16, 0.26)],
		"death": [Rect2(0.35, 0.74, 0.16, 0.26), Rect2(0.51, 0.74, 0.20, 0.26), Rect2(0.72, 0.74, 0.28, 0.26)]
	}, true, {"attack": 0.72})
	build_character("boss", {
		"idle": row([0, 1, 2, 3], 0, 0.37),
		"walk": row([4, 5, 6, 7], 0, 0.37),
		"attack": [Rect2(0, 0.38, 0.17, 0.30), Rect2(0.18, 0.38, 0.16, 0.30), Rect2(0.35, 0.38, 0.15, 0.30), Rect2(0.51, 0.38, 0.24, 0.30), Rect2(0.76, 0.38, 0.24, 0.30)],
		"hurt": [Rect2(0, 0.69, 0.17, 0.31), Rect2(0.17, 0.69, 0.17, 0.31), Rect2(0.34, 0.69, 0.17, 0.31)],
		"death": [Rect2(0.51, 0.69, 0.17, 0.31), Rect2(0.68, 0.69, 0.17, 0.31), Rect2(0.85, 0.69, 0.15, 0.31)]
	}, true)
	build_icons()
	build_effects()
	print("ATLAS_BUILD: %d errors" % failures)
	quit(1 if failures else 0)

func pixel_rect(normalized: Rect2, size: Vector2i) -> Rect2i:
	var start = Vector2i((normalized.position * Vector2(size)).round())
	var end = Vector2i((normalized.end * Vector2(size)).round())
	return Rect2i(start, end - start).intersection(Rect2i(Vector2i.ZERO, size))

func used_region(image: Image, region: Rect2i) -> Rect2i:
	var used = image.get_region(region).get_used_rect()
	if not used.has_area():
		failures += 1
		push_error("Empty frame at %s" % region)
		return region
	return Rect2i(used.position + region.position, used.size)

func build_character(key: String, layouts: Dictionary, flip: bool = false, scales: Dictionary = {}) -> void:
	var texture = load(ROOT + key + ".png") as Texture2D
	if texture == null:
		failures += 1
		return
	var source = texture.get_image()
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var pivots: Dictionary = {}
	var reference_height = 1.0
	for animation in layouts:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, animation in ["idle", "walk"])
		frames.set_animation_speed(animation, 5 if animation == "idle" else 12)
		var points: Array = []
		for i in range(layouts[animation].size()):
			var cell = pixel_rect(layouts[animation][i], source.get_size())
			var bounds = used_region(source, cell)
			if animation == "idle" and i == 0:
				reference_height = bounds.size.y
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(bounds)
			atlas.filter_clip = true
			frames.add_frame(animation, atlas)
			# Anchor at the center of opaque pixels near the feet, not at the
			# weapon/particle bounding-box center. Death keeps its original cell base.
			var pivot = ground_pivot(source, bounds)
			if animation == "death":
				pivot.y = cell.end.y - bounds.position.y - source.get_height() * 0.015
			points.append(pivot)
		pivots[animation] = points
	frames.set_meta("pivots", pivots)
	frames.set_meta("reference_height", reference_height)
	frames.set_meta("flip_left", flip)
	frames.set_meta("scales", scales)
	if ResourceSaver.save(frames, ROOT + "animations/" + key + ".tres") != OK:
		failures += 1
	print("  %s: %d animations" % [key, frames.get_animation_names().size()])

func ground_pivot(source: Image, bounds: Rect2i) -> Vector2:
	var total: float = 0
	var samples: int = 0
	var strip = maxi(2, int(bounds.size.y * 0.08))
	for y in range(bounds.end.y - strip, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if source.get_pixel(x, y).a > 0.7:
				total += x - bounds.position.x
				samples += 1
	return Vector2(total / samples if samples else bounds.size.x * 0.5, bounds.size.y)

func build_icons() -> void:
	var texture = load(ROOT + "relics.png") as Texture2D
	if texture == null:
		failures += 1
		return
	var source = texture.get_image()
	for i in range(7):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(used_region(source, pixel_rect(Rect2(i / 7.0, 0, 1 / 7.0, 1), source.get_size())))
		atlas.filter_clip = true
		ResourceSaver.save(atlas, ROOT + "animations/relic_%d.tres" % i)

func build_effects() -> void:
	var texture = load(ROOT + "effects.png") as Texture2D
	if texture == null:
		failures += 1
		return
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var names = ["slash", "critical", "magic", "embers"]
	for y in range(4):
		frames.add_animation(names[y])
		frames.set_animation_loop(names[y], false)
		frames.set_animation_speed(names[y], 12)
		for x in range(3 if y == 0 else 4):
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(pixel_rect(Rect2(x * 0.25, y * 0.25, 0.25, 0.25), Vector2i(texture.get_size())))
			atlas.filter_clip = true
			frames.add_frame(names[y], atlas)
	ResourceSaver.save(frames, ROOT + "animations/effects.tres")
