extends SceneTree
## Validates shipped art and the arena's animation transitions without a save file.
## godot --headless --path . --script tests/test_assets.gd

const Library = preload("res://scripts/art_library.gd")
const Arena = preload("res://scripts/arena.gd")
const State = preload("res://scripts/run_state.gd")

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func read_texture(path: String, transparent: bool = true) -> Image:
	check(ResourceLoader.exists(path), "Texture is importable: " + path)
	if not ResourceLoader.exists(path):
		return null
	var texture = load(path) as Texture2D
	check(texture != null, "Resource is a texture: " + path)
	if texture == null:
		return null
	var image = texture.get_image()
	check(image != null and not image.is_empty(), "Texture has pixel data: " + path)
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	if transparent:
		check(image.detect_alpha() != Image.ALPHA_NONE, "Texture has real transparency: " + path)
	check(image.get_used_rect().has_area(), "Texture is not entirely transparent: " + path)
	return image

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(FileAccess.file_exists(Library.MANIFEST), "Atlas manifest ships with the project")
	if not FileAccess.file_exists(Library.MANIFEST):
		quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(Library.MANIFEST))
	check(data is Dictionary, "Atlas manifest contains a dictionary")
	if not data is Dictionary:
		quit(1)
		return
	for section in ["characters", "relics", "fx", "ui"]:
		check(data.has(section) and data[section] is Dictionary, "Atlas section exists: " + section)
	if failures > 0:
		quit(1)
		return
	var lib = Library.shared()
	for key in ["hero", "slime", "wisp", "sentinel", "boss", "companion"]:
		check(data.characters.has(key), "Playable character exists: " + key)
	for key in data.characters:
		var entry: Dictionary = data.characters[key]
		var image = read_texture(entry.texture)
		if image == null:
			continue
		check(float(entry.scale) > 0, "Character scale is positive: " + key)
		var bounds = Rect2i(Vector2i.ZERO, image.get_size())
		var regions: Array[Rect2i] = []
		for index in range(entry.frames.size()):
			var f: Array = entry.frames[index]
			var label = "%s frame %d" % [key, index]
			check(f.size() == 6, "Frame has region and pivot: " + label)
			if f.size() != 6:
				continue
			var region = Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
			check(region.has_area() and bounds.encloses(region), "Frame stays inside its atlas: " + label)
			check(is_finite(float(f[4])) and is_finite(float(f[5])), "Frame pivot is finite: " + label)
			if bounds.encloses(region) and region.has_area():
				check(image.get_region(region).get_used_rect().has_area(), "Frame contains visible pixels: " + label)
			var overlaps = false
			for existing in regions:
				overlaps = overlaps or existing.intersects(region)
			check(not overlaps, "Frame does not contain pixels of a neighbour: " + label)
			regions.append(region)
		var expected = ["idle"] if key == "companion" else ["idle", "walk", "attack", "hurt", "death"]
		for name in expected:
			check(entry.animations.has(name), "Animation exists: %s/%s" % [key, name])
		for name in entry.animations:
			var anim: Dictionary = entry.animations[name]
			check(float(anim.fps) > 0 and not anim.frames.is_empty(), "Animation can advance: %s/%s" % [key, name])
			var valid = not anim.frames.is_empty() and float(anim.fps) > 0
			for index in anim.frames:
				var in_range = int(index) >= 0 and int(index) < entry.frames.size()
				check(in_range, "Animation references an existing frame: %s/%s" % [key, name])
				valid = valid and in_range
			if valid:
				var end = lib.frame_at(key, name, lib.anim_length(key, name) + 0.00001)
				var expected_index = anim.frames[0] if anim.loop else anim.frames.back()
				check(end == entry.frames[int(expected_index)], "Animation loops or holds its final frame: %s/%s" % [key, name])
	for id in data.relics:
		read_texture(data.relics[id])
	for id in data.fx:
		var effect: Dictionary = data.fx[id]
		var image = read_texture(effect.texture)
		if image != null:
			check(image.get_size() == Vector2i(int(effect.frames) * int(effect.size), int(effect.size)), "Effect cells match the atlas: " + id)
			for i in range(int(effect.frames)):
				var region = Rect2i(i * int(effect.size), 0, int(effect.size), int(effect.size))
				check(image.get_region(region).get_used_rect().has_area(), "Effect frame is visible: %s/%d" % [id, i])
	for id in data.ui:
		var entry = data.ui[id]
		read_texture(entry.texture if entry is Dictionary else entry, id in ["button", "shard"])
	for path in Library.BACKGROUNDS:
		var image = read_texture(path, false)
		if image != null:
			check(image.get_size() == Vector2i(1024, 800), "Backdrop matches stage coordinates: " + path)
	check(lib.heading_font.has_char(0x00F1) and lib.heading_font.has_char(0x00E1), "Font renders Spanish accents")

	# An enemy defeated during its lunge must not move the next enemy.
	var state = State.new()
	state.restart()
	var arena = Arena.new()
	arena.state = state
	arena.size = Vector2(760, 590)
	root.add_child(arena)
	arena.set_process(false)
	await process_frame
	arena.enemy.set_meta("lunge", 0.15)
	arena.enemy.set_meta("walk_in", 300.0)
	arena.enemy.set_meta("walking", true)
	arena.enemy.offset = Vector2(-100, 0)
	arena.enemy.speed = 0.25
	state.room = 2
	state.spawn_enemy(false)
	arena.sync_enemy(false)
	check(not arena.enemy.has_meta("lunge") and not arena.enemy.has_meta("walk_in") and not arena.enemy.has_meta("walking"), "New enemy clears the previous enemy's movement")
	check(arena.enemy.offset == Vector2.ZERO and arena.enemy.speed == 1.0, "New enemy resets displacement and animation speed")
	state.paused = true
	state.wisps = 3
	arena.reduced_motion = true
	arena.shake = 10
	arena.flash = 0.5
	var companion: Vector2 = arena.companion_pos(0)
	var ember: Vector2 = arena.ember_stage_pos()
	var ash: Vector2 = arena.ash[0].pos
	arena._process(0.2)
	check(arena.companion_pos(0) == companion and arena.ember_stage_pos() == ember and arena.ash[0].pos == ash, "Reduced motion stops ambient movement")
	check(arena.enemy.bob == 0 and arena.shake == 0 and arena.flash == 0, "Reduced motion removes hovering, screen shake and full-screen flashes")
	arena.reduced_motion = false
	arena._process(0.2)
	check(arena.companion_pos(0) != companion and arena.ash[0].pos != ash, "Ambient movement resumes when enabled")
	arena.queue_free()
	await process_frame
	Library.release()
	print("Assets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
