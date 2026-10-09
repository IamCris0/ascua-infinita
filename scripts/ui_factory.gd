extends RefCounted
## Builds the recurring interface pieces: labels, buttons with sound, cards,
## icon slots and stone panels. Shared by every screen so they look alike.

const Kit = preload("res://scripts/ui_kit.gd")
const StonePanel = preload("res://scripts/stone_panel.gd")

var lib
var audio
var coin_tex: Texture2D

func _init(library, audio_director, coin: Texture2D) -> void:
	lib = library
	audio = audio_director
	coin_tex = coin

func label(parent: Node, value: String, font_size: int = 17, color: Color = Kit.TEXT, heading: bool = false) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if heading:
		l.add_theme_font_size_override("font_size", int(font_size * 1.22))
		l.add_theme_font_override("font", lib.heading_font)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.9))
	if parent:
		parent.add_child(l)
	return l

func wrap_label(parent: Node, value: String, font_size: int = 15, color: Color = Kit.MUTED) -> Label:
	var l = label(parent, value, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l

func button(parent: Node, value: String, callback: Callable, height: float = 52, font_size: int = 19) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = height
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(font_size * 1.22))
	b.pressed.connect(func():
		audio.play("ui_click", 0.04)
		callback.call()
	)
	b.mouse_entered.connect(func():
		if not b.disabled:
			audio.play("ui_hover", 0.05, 0.0, 0.03)
	)
	if parent:
		parent.add_child(b)
	return b

func small_button(parent: Node, value: String, callback: Callable) -> Button:
	var b = button(parent, value, callback, 34, 16)
	b.add_theme_stylebox_override("normal", Kit.flat(Kit.SLOT, Color("3b404c"), 5, 2, 6))
	b.add_theme_stylebox_override("hover", Kit.flat(Color("232731"), Kit.COPPER, 5, 2, 6))
	b.add_theme_stylebox_override("pressed", Kit.flat(Color("2c2218"), Kit.COPPER, 5, 2, 6))
	b.add_theme_stylebox_override("disabled", Kit.flat(Kit.SLOT, Color("23262e"), 5, 2, 6))
	return b

func stone(parent: Node, min_width: float = 0, straps: bool = true) -> VBoxContainer:
	var p = StonePanel.new()
	p.straps = straps
	p.custom_minimum_size.x = min_width
	p.add_theme_stylebox_override("panel", Kit.stone_style())
	parent.add_child(p)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(v)
	return v

func card(parent: Node, color: Color = Kit.SLATE_DARK, border: Color = Kit.LINE, margin: float = 10) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.flat(color, border, 6, 2, margin))
	parent.add_child(p)
	return p

func icon_slot(parent: Node, texture: Texture2D, side: float = 48, border: Color = Kit.LINE) -> TextureRect:
	var slot = PanelContainer.new()
	slot.add_theme_stylebox_override("panel", Kit.slot_style(border))
	slot.custom_minimum_size = Vector2(side, side)
	parent.add_child(slot)
	var t = TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.custom_minimum_size = Vector2(side - 10, side - 10)
	slot.add_child(t)
	return t

func icon(parent: Node, texture: Texture2D, side: float) -> TextureRect:
	var t = TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if texture == coin_tex else CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(t)
	return t

func spacer(parent: Node, height: float = -1) -> Control:
	var c = Control.new()
	if height < 0:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.custom_minimum_size.y = height
	parent.add_child(c)
	return c

func hspacer(parent: Node) -> Control:
	var c = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())

## Overline and title; returns the title label so it can change later.
func header(parent: Node, overline: String, title: String) -> Label:
	label(parent, overline, 14, Kit.COPPER, true)
	if not title.is_empty():
		return label(parent, title, 25, Kit.TEXT, true)
	return null
