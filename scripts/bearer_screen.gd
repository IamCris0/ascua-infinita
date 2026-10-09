extends RefCounted
## The bearers at the bonfire: one card each with the recoloured figure, the
## passive, the Destello technique and, while locked, how to earn it.
## Rules live in run_state.gd; the choice goes back through main.gd.

const Kit = preload("res://scripts/ui_kit.gd")
const SHADER = preload("res://assets/shaders/actor.gdshader")
const COLORS = {"bearer": Color("f2c47c"), "sentinel": Color("8fb8ff"), "summoner": Color("7fe0bf"), "wanderer": Color("c48cf5")}

static func build(game, parent: VBoxContainer) -> void:
	var state = game.state
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	for id in state.BEARER_IDS:
		_card(game, row, id)

## How far the player is from the achievement that unlocks a bearer.
static func unlock_text(state, id: String) -> String:
	match state.BEARERS[id].unlock:
		"parry": return "Logra 25 paradas perfectas (%d/25)." % mini(state.total_parries, 25)
		"bell": return "Derrota a la Campanera Vacía, jefa de las Criptas."
		"chests": return "Abre 15 cofres (%d/15)." % mini(state.total_chests, 15)
	return ""

static func _card(game, row: HBoxContainer, id: String) -> void:
	var ui = game.ui
	var state = game.state
	var spec: Dictionary = state.BEARERS[id]
	var unlocked: bool = state.bearer_unlocked_by(id)
	var chosen: bool = state.bearer == id
	var color: Color = COLORS[id]
	var card = ui.card(row, Color("1d1a22") if chosen else Kit.SLATE_DARK, color if chosen else (color.darkened(0.55) if unlocked else Kit.LINE), 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if chosen:
		card.get_theme_stylebox("panel").set_border_width_all(3)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	# The figure, in the bearer's colours; a dark silhouette while locked.
	var figure = TextureRect.new()
	figure.texture = game.lib.frame_icon("hero", 0)
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.custom_minimum_size = Vector2(0, 170)
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("hue_shift", spec.hue)
	material.set_shader_parameter("brightness", 1.0 if unlocked else 0.12)
	material.set_shader_parameter("saturation", 1.0 if unlocked else 0.0)
	figure.material = material
	v.add_child(figure)
	ui.label(v, spec.name, 22, color if unlocked else Kit.MUTED, true)
	ui.label(v, spec.role.to_upper(), 13, Kit.COPPER, true)
	ui.wrap_label(v, spec.passive, 14, Kit.TEXT if unlocked else Kit.MUTED).custom_minimum_size.y = 62
	ui.label(v, spec.technique, 16, Kit.RUNE if unlocked else Kit.MUTED, true)
	ui.wrap_label(v, spec.technique_text, 13, Color("cdbff0") if unlocked else Kit.MUTED).custom_minimum_size.y = 54
	ui.spacer(v, 4)
	if not unlocked:
		ui.wrap_label(v, "BLOQUEADO · " + unlock_text(state, id), 13, Kit.GOLD).custom_minimum_size.y = 36
		ui.button(v, "BLOQUEADO", func(): pass, 46, 16).disabled = true
	elif chosen:
		ui.wrap_label(v, "Saldrá en la próxima expedición.", 13, Kit.TEAL).custom_minimum_size.y = 36
		ui.button(v, "ELEGIDO", func(): pass, 46, 16).disabled = true
	else:
		ui.wrap_label(v, "", 13).custom_minimum_size.y = 36
		ui.button(v, "ELEGIR", func(): game.choose_bearer(id), 46, 16)
