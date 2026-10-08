extends RefCounted
## Loads the prepared atlases (assets/art/atlas.json) once and shares them.
## The atlas is produced by tools/sprites/build_art.py from the Gemini sheets.

const MANIFEST = "res://assets/art/atlas.json"
const CHARACTER_OVERRIDES = "res://assets/art/imagegen/characters.json"
const BACKGROUNDS = ["res://assets/gemini/backgrounds/garden.png", "res://assets/gemini/backgrounds/crypt.png", "res://assets/gemini/backgrounds/forge.png"]
# Shrine (cells 0-3: unlit, lit, flaring, spent) and altar (4-7: dormant,
# awake, pact sealed, broken), prepared by tools/sprites/key_imagegen.py.
const EVENTS = "res://assets/art/imagegen/final/events-v1.png"
const EVENT_CELL = 360

static var _shared = null

var characters: Dictionary = {}
var textures: Dictionary = {}
var fx: Dictionary = {}
var relics: Dictionary = {}
var ui: Dictionary = {}
var backgrounds: Array[Texture2D] = []
var events: Texture2D
var heading_font: Font
var button_font: Font
var logo_font: Font

static func shared():
	if _shared == null:
		_shared = load("res://scripts/art_library.gd").new()
	return _shared

static func release() -> void:
	_shared = null

func _init() -> void:
	var file = FileAccess.open(MANIFEST, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if FileAccess.file_exists(CHARACTER_OVERRIDES):
		var overrides = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_OVERRIDES))
		data.characters.merge(overrides, true)
	for key in data.characters:
		var c: Dictionary = data.characters[key]
		characters[key] = c
		textures[key] = load(c.texture)
	for key in data.fx:
		fx[key] = data.fx[key]
		fx[key]["tex"] = load(data.fx[key].texture)
	for key in data.relics:
		relics[key] = load(data.relics[key])
	for key in data.ui:
		var entry = data.ui[key]
		ui[key] = load(entry.texture if entry is Dictionary else entry)
	ui["button_margin"] = data.ui.button.margin
	for path in BACKGROUNDS:
		backgrounds.append(load(path))
	events = load(EVENTS)
	heading_font = _font("res://assets/fonts/Jersey10-Regular.ttf")
	button_font = heading_font
	logo_font = heading_font

func _font(path: String) -> Font:
	var f: FontFile = load(path)
	if f == null:
		return ThemeDB.fallback_font
	var copy: FontFile = f.duplicate()
	copy.fallbacks = [ThemeDB.fallback_font]
	return copy

# ---------------------------------------------------------------- animation
func anim_frames(key: String, anim: String) -> Array:
	var c: Dictionary = characters[key]
	if not c.animations.has(anim):
		anim = "idle"
	return c.animations[anim].frames

func anim_info(key: String, anim: String) -> Dictionary:
	var c: Dictionary = characters[key]
	return c.animations.get(anim, c.animations.idle)

func anim_length(key: String, anim: String) -> float:
	var info = anim_info(key, anim)
	return info.frames.size() / float(info.fps)

## Returns [x, y, w, h, pivot_x, pivot_y] for the frame shown after `elapsed` seconds.
func frame_at(key: String, anim: String, elapsed: float) -> Array:
	var info = anim_info(key, anim)
	var count: int = info.frames.size()
	var index = int(maxf(0, elapsed) * float(info.fps))
	index = index % count if info.loop else mini(index, count - 1)
	return characters[key].frames[int(info.frames[index])]

func frame_height(key: String) -> float:
	return float(characters[key].frames[0][3]) * float(characters[key].scale)

func draw_frame(canvas: CanvasItem, key: String, frame: Array, feet: Vector2, scale: float, color: Color = Color.WHITE) -> void:
	var parts: Dictionary = characters[key].get("parts", {})
	var index = str(characters[key].frames.find(frame))
	if parts.has(index):
		for part in parts[index]:
			_draw_region(canvas, key, part, feet, scale, color)
	else:
		_draw_region(canvas, key, frame, feet, scale, color)

func _draw_region(canvas: CanvasItem, key: String, frame: Array, feet: Vector2, scale: float, color: Color) -> void:
	var s = scale * float(characters[key].scale)
	var size = Vector2(frame[2], frame[3]) * s
	var pivot = Vector2(frame[4], frame[5]) * s
	var pos = feet - pivot
	canvas.draw_texture_rect_region(textures[key], Rect2(pos, size), Rect2(frame[0], frame[1], frame[2], frame[3]), color)

## Draws one effect frame; returns false once the effect has finished.
func draw_fx(canvas: CanvasItem, name: String, elapsed: float, center: Vector2, width: float, color: Color = Color.WHITE, fps: float = 14.0, rotation: float = 0.0) -> bool:
	var info: Dictionary = fx[name]
	var index = int(elapsed * fps)
	if index >= int(info.frames):
		return false
	var side = float(info.size)
	if rotation != 0.0:
		canvas.draw_set_transform(center, rotation, Vector2.ONE)
		canvas.draw_texture_rect_region(info.tex, Rect2(-Vector2.ONE * width * 0.5, Vector2.ONE * width), Rect2(index * side, 0, side, side), color)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(info.tex, Rect2(center - Vector2.ONE * width * 0.5, Vector2.ONE * width), Rect2(index * side, 0, side, side), color)
	return true

# ---------------------------------------------------------------- icons
func frame_icon(key: String, index: int, crop_top: float = 1.0) -> AtlasTexture:
	var f: Array = characters[key].frames[index]
	var a = AtlasTexture.new()
	a.atlas = textures[key]
	a.region = Rect2(f[0], f[1], f[2], f[3] * crop_top)
	return a

func fx_icon(name: String, index: int, inset: float = 0.18) -> AtlasTexture:
	var side = float(fx[name].size)
	var a = AtlasTexture.new()
	a.atlas = fx[name].tex
	a.region = Rect2(index * side + side * inset, side * inset, side * (1 - 2 * inset), side * (1 - 2 * inset))
	return a

func portrait(key: String) -> AtlasTexture:
	var region: Array = characters[key].portrait
	var a = AtlasTexture.new()
	a.atlas = textures[key]
	a.region = Rect2(region[0], region[1], region[2], region[3])
	return a

func event_art(index: int) -> AtlasTexture:
	var a = AtlasTexture.new()
	a.atlas = events
	a.region = Rect2((index % 4) * EVENT_CELL, int(index / 4.0) * EVENT_CELL, EVENT_CELL, EVENT_CELL)
	return a

func upgrade_icon(kind: int) -> Texture2D:
	if kind == 2 and characters.hero.has("portrait"):
		return portrait("hero")
	match kind:
		0: return fx_icon("slash", 2, 0.12)
		1: return frame_icon("companion", 0)
		2: return frame_icon("hero", 0, 0.42)
		_: return fx_icon("critical", 1, 0.12)

func legacy_icon(kind: int) -> Texture2D:
	match kind:
		6: return relics.eye
		7: return fx_icon("slash", 2, 0.12)
		8: return fx_icon("critical", 1, 0.12)
		9: return frame_icon("companion", 0)
		10: return relics.clock
		11: return fx_icon("magic", 1, 0.12)
		12: return relics.ash
		13: return fx_icon("embers", 0, 0.1)
	return [ui.staff, relics.heart, ui.lantern_star, relics.coin, ui.lantern_lit, relics.storm][kind]
