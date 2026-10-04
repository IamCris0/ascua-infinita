extends Node2D
## One animated character on the stage. Frames come from ArtLibrary; colour
## treatment (biome hue, hit flash, fades) runs in assets/shaders/actor.gdshader.

const SHADER = preload("res://assets/shaders/actor.gdshader")

var lib
var key: String = "hero"
var anim: String = "idle"
var anim_time: float = 0.0
var after: String = "idle"
var hold: bool = false
var speed: float = 1.0
var base_scale: float = 1.0
var tint: Color = Color.WHITE
var alpha: float = 1.0
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var hue: float = 0.0
var brightness: float = 1.0
var saturation: float = 1.0
var offset: Vector2 = Vector2.ZERO
var bob: float = 0.0
var clock: float = 0.0

func _init(library, character: String = "hero") -> void:
	lib = library
	key = character
	var m = ShaderMaterial.new()
	m.shader = SHADER
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func set_character(character: String) -> void:
	key = character
	play("idle")

func play(name: String, then: String = "idle", keep_last: bool = false) -> void:
	anim = name
	anim_time = 0.0
	after = then
	hold = keep_last

func playing(name: String) -> bool:
	return anim == name

func finished() -> bool:
	var info = lib.anim_info(key, anim)
	return not info.loop and anim_time >= lib.anim_length(key, anim)

func height() -> float:
	return lib.frame_height(key) * base_scale

func _process(delta: float) -> void:
	clock += delta
	anim_time += delta * speed
	flash = maxf(0.0, flash - delta * 5.0)
	offset = offset.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	if finished() and not hold:
		anim = after
		anim_time = 0.0
		after = "idle"
	var m: ShaderMaterial = material
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("flash_color", flash_color)
	m.set_shader_parameter("hue_shift", hue)
	m.set_shader_parameter("brightness", brightness)
	m.set_shader_parameter("saturation", saturation)
	queue_redraw()

func _draw() -> void:
	if alpha <= 0.01:
		return
	var frame = lib.frame_at(key, anim, anim_time)
	var lift = Vector2(0, -abs(sin(clock * 2.4)) * bob) if bob > 0 else Vector2.ZERO
	lib.draw_frame(self, key, frame, offset + lift, base_scale, Color(tint, tint.a * alpha))
