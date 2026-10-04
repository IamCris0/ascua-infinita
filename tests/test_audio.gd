extends SceneTree
## Rapid music transitions and boss-cue attenuation use independent envelopes.
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var audio = load("res://scripts/audio_director.gd").new()
	root.add_child(audio)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	check(audio.music.size() == 6 and audio.streams.size() == 27, "All music and effects can be loaded")
	audio.play_music("garden", 0.8)
	await create_timer(0.05).timeout
	audio.duck(12, 0.1)
	audio.play_music("boss", 0.6)
	await create_timer(0.05).timeout
	audio.play_music("garden", 0.1)
	await create_timer(1.0).timeout
	check(audio.current_track == "garden" and audio.deck[audio.active_deck].playing, "The latest track remains playing after interrupted fades")
	check(is_equal_approx(audio.deck[audio.active_deck].volume_db, -6.0), "An older fade cannot silence the active track")
	check(not audio.deck[1 - audio.active_deck].playing, "The inactive deck stops after the final fade")
	check(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MusicDuck"))), "Boss-cue attenuation returns to neutral")
	audio.duck(9, 0.8)
	await create_timer(0.2).timeout
	audio.duck(3, 0.0)
	await create_timer(0.9).timeout
	check(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MusicDuck"))), "A replacement cue cancels the earlier attenuation")
	audio.queue_free()
	# Allow the audio thread to release the stopped Ogg playback before exit.
	await create_timer(0.15).timeout
	print("AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
