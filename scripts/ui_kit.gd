extends RefCounted
## Palette, theme and reusable styles. Colours follow the Gemini interface
## reference: slate stone, iron, copper lettering, rune violet and soul green.

const INK = Color("0a0c11")
const SLATE = Color("272b35")
const SLATE_DARK = Color("181b22")
const SLATE_LIGHT = Color("3a404d")
const SLOT = Color("12141a")
const LINE = Color("07080b")
const TEXT = Color("ede6d6")
const MUTED = Color("98a2b0")
const GOLD = Color("f2c47c")
const COPPER = Color("f0a368")
const TEAL = Color("7fe0bf")
const RUNE = Color("b18cf0")
const DANGER = Color("ec6d5d")

static func flat(color: Color, border: Color = LINE, radius: int = 6, border_width: int = 2, margin: float = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s

static func slot_style(border: Color = LINE) -> StyleBoxFlat:
	var s = flat(SLOT, border, 6, 2, 4)
	s.border_width_top = 3
	return s

static func stone_style(color: Color = SLATE) -> StyleBoxFlat:
	var s = flat(color, LINE, 8, 3, 22)
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s

static func button_texture(lib, tint: Color) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = lib.ui.button
	var m: Array = lib.ui.button_margin
	s.texture_margin_left = m[0]
	s.texture_margin_top = m[1]
	s.texture_margin_right = m[2]
	s.texture_margin_bottom = m[3]
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.modulate_color = tint
	return s

static func build_theme(lib) -> Theme:
	var t = Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", lib.button_font)
	t.set_font_size("font_size", "Button", 23)
	t.set_color("font_color", "Button", Color("f6dcc0"))
	t.set_color("font_hover_color", "Button", Color("fff3e2"))
	t.set_color("font_pressed_color", "Button", Color("ffd9a8"))
	t.set_color("font_focus_color", "Button", Color("fff3e2"))
	t.set_color("font_disabled_color", "Button", Color("7d7a76"))
	t.set_constant("outline_size", "Button", 4)
	t.set_color("font_outline_color", "Button", Color(0.05, 0.03, 0.02, 0.9))
	t.set_stylebox("normal", "Button", button_texture(lib, Color(1, 1, 1)))
	t.set_stylebox("hover", "Button", button_texture(lib, Color(1.22, 1.12, 1.02)))
	t.set_stylebox("pressed", "Button", button_texture(lib, Color(0.82, 0.78, 0.74)))
	t.set_stylebox("disabled", "Button", button_texture(lib, Color(0.48, 0.48, 0.52)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Check buttons and sliders inside option menus.
	t.set_font("font", "CheckButton", ThemeDB.fallback_font)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color("fff3e2"))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color("fff3e2"))
	t.set_stylebox("normal", "CheckButton", flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("hover", "CheckButton", flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("pressed", "CheckButton", flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("hover_pressed", "CheckButton", flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	var slider = flat(SLOT, LINE, 4, 2, 0)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	var area = flat(COPPER, Color(0, 0, 0, 0), 3, 0, 0)
	area.content_margin_top = 4
	area.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area)
	t.set_icon("grabber", "HSlider", _grabber(Color("f6dcc0")))
	t.set_icon("grabber_highlight", "HSlider", _grabber(Color("ffffff")))
	# Bars.
	t.set_stylebox("background", "ProgressBar", flat(SLOT, LINE, 4, 2, 0))
	t.set_stylebox("fill", "ProgressBar", flat(TEAL, Color(0, 0, 0, 0), 3, 0, 0))
	# Tooltips.
	var tip = flat(Color("15171e"), Color("6b5a44"), 6, 2, 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_color("separator", "HSeparator", Color("3b404c"))
	t.set_constant("separation", "HSeparator", 8)
	return t

static func _grabber(color: Color) -> ImageTexture:
	var img = Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(18):
		for x in range(18):
			var d = Vector2(x - 8.5, y - 8.5).length()
			if d < 8.5:
				img.set_pixel(x, y, LINE if d > 6.5 else color)
	return ImageTexture.create_from_image(img)

static func coin_texture() -> ImageTexture:
	# 12 x 12 pixel-art gold coin, scaled up by nearest filtering where drawn.
	var rows = [
		"....oooo....",
		"..ooyyyyoo..",
		".oyywwyyyyo.",
		".oywyyyyyyo.",
		"oyyyyddyyyyo",
		"oyyyyddyyyyo",
		"oyyyyddyyyyo",
		"oyyyyddyyyyo",
		".oyyyyyyyyo.",
		".oyyyyyyydo.",
		"..ooyyyydo..",
		"....oooo...."]
	var palette = {"o": Color("4a2a12"), "y": Color("f2c14e"), "w": Color("fff2b0"), "d": Color("c98a26")}
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(12):
		for x in range(12):
			var ch = rows[y][x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)
