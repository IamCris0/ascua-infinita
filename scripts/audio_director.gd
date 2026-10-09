extends Node
## Music with crossfades plus a pooled, pitch-varied sound-effect player.
## Volumes are routed through the "Music" and "SFX" buses created at runtime.

const SFX_DIR = "res://assets/audio/sfx/"
const MUSIC_DIR = "res://assets/audio/music/"
const SFX = ["hit_1", "hit_2", "hit_3", "critical", "burst", "hurt", "coin", "buy", "relic", "offer", "parry", "guard", "weak_appear", "weak_hit", "advance",
	"die_slime", "die_wisp", "die_sentinel", "die_boss", "boss_appear", "boss_charge", "interrupt",
	"ember_appear", "ember_take", "fall", "rebirth", "heal", "ui_hover", "ui_click", "ui_open", "ui_close", "ui_denied"]
const TRACKS = ["menu", "garden", "crypt", "forge", "boss", "camp"]
# Per-sound base volume (dB) so the mix sits well together.
const LEVELS = {"ui_hover": -10.0, "ui_click": -6.0, "hit_1": -4.0, "hit_2": -4.0, "hit_3": -4.0, "coin": -8.0,
	"ember_appear": -4.0, "offer": -4.0, "heal": -3.0, "guard": -8.0, "weak_appear": -6.0, "advance": -9.0}

var streams: Dictionary = {}
var music: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var next_player: int = 0
var deck: Array[AudioStreamPlayer] = []
var active_deck: int = 0
var current_track: String = ""
var muted_for_tests: bool = false
var cooldowns: Dictionary = {}
var music_tween: Tween
var duck_tween: Tween

func _exit_tree() -> void:
	for player in deck + pool:
		player.stop()
	for tween in [music_tween, duck_tween]:
		if tween and tween.is_valid():
			tween.kill()
	music_tween = null
	duck_tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("MusicDuck", "Music")
	for name in SFX:
		var path = SFX_DIR + name + ".wav"
		if ResourceLoader.exists(path):
			streams[name] = load(path)
	for name in TRACKS:
		var path = MUSIC_DIR + name + ".ogg"
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			music[name] = stream
	for i in range(14):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	for i in range(2):
		var d = AudioStreamPlayer.new()
		d.bus = "MusicDuck"
		d.volume_db = -80
		add_child(d)
		deck.append(d)

func _ensure_bus(name: String, destination: String = "Master") -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, destination)

func apply_volumes(master: float, music_level: float, sfx_level: float) -> void:
	_set_bus("Master", master)
	_set_bus("Music", music_level)
	_set_bus("SFX", sfx_level)

func _set_bus(name: String, linear: float) -> void:
	var index = AudioServer.get_bus_index(name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))

func play(name: String, pitch_jitter: float = 0.0, volume_db: float = 0.0, min_gap: float = 0.0) -> void:
	if muted_for_tests or not streams.has(name):
		return
	var now = Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(cooldowns.get(name, -10.0)) < min_gap:
		return
	cooldowns[name] = now
	var p = pool[next_player % pool.size()]
	next_player += 1
	p.stream = streams[name]
	p.volume_db = float(LEVELS.get(name, 0.0)) + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func play_hit(critical: bool) -> void:
	if critical:
		play("critical", 0.06, 0.0, 0.05)
	else:
		play("hit_%d" % randi_range(1, 3), 0.08, 0.0, 0.045)

func play_music(track: String, fade: float = 1.4) -> void:
	if track == current_track or not music.has(track):
		return
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	current_track = track
	var old = deck[active_deck]
	active_deck = 1 - active_deck
	var new = deck[active_deck]
	new.stream = music[track]
	new.volume_db = -40
	if not muted_for_tests:
		new.play()
	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(new, "volume_db", -6.0, fade).set_trans(Tween.TRANS_SINE)
	music_tween.tween_property(old, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
	music_tween.chain().tween_callback(func(): if old != deck[active_deck]: old.stop())

func duck(amount_db: float, seconds: float) -> void:
	# Attenuation is separate from deck fades, so a boss cue cannot revive or
	# silence the wrong deck when the player changes screens quickly.
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	var level = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MusicDuck"))
	duck_tween = create_tween()
	duck_tween.tween_method(_set_duck_db, level, -maxf(0.0, amount_db), 0.15)
	duck_tween.tween_interval(maxf(0.0, seconds))
	duck_tween.tween_method(_set_duck_db, -maxf(0.0, amount_db), 0.0, 0.6)

func _set_duck_db(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MusicDuck"), value)
