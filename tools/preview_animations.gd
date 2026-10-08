extends SceneTree
## Local preview of the same textures, pivots and animation sequences as the game.
var gallery

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.title = "Ascua Infinita — Animaciones"
	gallery = Gallery.new()
	root.add_child.call_deferred(gallery)

class Gallery extends Control:
	var lib
	var elapsed = 0.0
	var rate = 1.0
	var paused = false
	var animation = "attack"
	var captured = false
	var keys = ["hero", "slime", "wisp", "sentinel", "boss", "bell"]
	var names = ["Portador", "Gelatina", "Lucero", "Centinela", "Rey sin Brasa"]
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lib = load("res://scripts/art_library.gd").shared()
		var row = HBoxContainer.new()
		row.position = Vector2(30, 84)
		row.add_theme_constant_override("separation", 20)
		add_child(row)
		var choice = OptionButton.new()
		for title in ["Reposo", "Carrera", "Ataque", "Daño", "Muerte"]:
			choice.add_item(title)
		choice.select(2)
		choice.item_selected.connect(func(i): animation = ["idle", "walk", "attack", "hurt", "death"][i]; elapsed = 0)
		row.add_child(choice)
		var pause = Button.new()
		pause.text = "Pausar / continuar"
		pause.pressed.connect(func(): paused = not paused)
		row.add_child(pause)
		var slow = CheckButton.new()
		slow.text = "Cámara lenta"
		slow.toggled.connect(func(on): rate = 0.3 if on else 1.0)
		row.add_child(slow)
	func _process(delta: float) -> void:
		if not paused:
			elapsed += delta * rate
		queue_redraw()
		if "--capture-gallery" in OS.get_cmdline_user_args() and not captured and elapsed > 0.2:
			captured = true
			capture.call_deferred()
	func capture() -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/animations.png")
		get_tree().quit()
	func _draw() -> void:
		if lib == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("141923"))
		draw_string(lib.heading_font, Vector2(30, 54), "ASCUA INFINITA · PERSONAJES EN MOVIMIENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("ffcf7b"))
		var width = size.x / keys.size()
		for i in range(keys.size()):
			var key = keys[i]
			var x = width * (i + 0.5)
			var feet = Vector2(x, size.y * 0.72)
			draw_line(Vector2(x - width * 0.43, feet.y + 2), Vector2(x + width * 0.43, feet.y + 2), Color("425260"), 2)
			var info = lib.anim_info(key, animation)
			var length = lib.anim_length(key, animation)
			var t = elapsed if info.loop else fmod(elapsed, length + 0.65)
			lib.draw_frame(self, key, lib.frame_at(key, animation, t), feet, 1.0)
			draw_string(lib.heading_font, Vector2(x - width * 0.43, size.y * 0.84), names[i], HORIZONTAL_ALIGNMENT_CENTER, width * 0.86, 26, Color("d6e2e8"))
			draw_string(lib.heading_font, Vector2(x - width * 0.43, size.y * 0.89), "%d poses · %d fps" % [info.frames.size(), info.fps], HORIZONTAL_ALIGNMENT_CENTER, width * 0.86, 20, Color("86e0bd"))
