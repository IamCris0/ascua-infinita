extends SceneTree
const State = preload("res://scripts/run_state.gd")
const SAVE = "user://qa_journey.json"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func milestone():
	var s = State.new()
	s.rng.seed = 19
	s.restart()
	s.room = 5
	s.spawn_enemy(false)
	s.damage_enemy(1e9)
	return s

func _initialize() -> void:
	var s = milestone()
	check(s.room == 6 and s.journey_phase == "route" and s.offers.size() == 3, "Every fifth victory grants a relic and a route")
	check(not s.choose_route(0), "A route cannot bypass the relic choice")
	var health = s.hp
	var target = s.enemy_hp
	s.tick(60)
	check(s.hp == health and s.enemy_hp == target and not s.click() and not s.burst(), "Decisions freeze both sides of combat")
	check(s.save_game(SAVE), "Pending milestone can be saved")
	var restored = State.new()
	check(restored.load_game(SAVE, false) and restored.offers == s.offers and restored.encounter_kind == s.encounter_kind and restored.journey_phase == "route", "Reload preserves the relic offers and announced encounter")
	s.choose_relic(s.offers[0])
	check(not s.choose_route(-1) and not s.choose_route(3), "Invalid route choices are rejected")
	s.hp = 10
	check(s.choose_route(0) and is_equal_approx(s.hp, 10 + s.max_hp() * 0.2) and not s.enemy_elite, "Safe path heals and guarantees a normal rival")
	var healed = s.hp
	check(not s.choose_route(0) and s.hp == healed, "A route cannot heal twice")
	check(s.active(), "Combat resumes after a route")
	s = milestone()
	s.choose_relic(s.offers[0])
	check(s.choose_route(1) and s.enemy_elite and s.active(), "Elite path creates an elite opponent")
	check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.enemy_elite and is_equal_approx(restored.enemy_max, s.enemy_max), "The chosen elite remains an elite on reload")
	for kind in ["shrine", "merchant", "altar"]:
		s = milestone()
		s.choose_relic(s.offers[0])
		s.encounter_kind = kind
		check(s.choose_route(2) and s.journey_phase == "event" and not s.active(), "Event blocks combat: " + kind)
		check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.encounter_kind == kind and restored.journey_phase == "event", "Pending event survives reload: " + kind)
		if kind == "merchant":
			s.gold = 0
			check(not s.resolve_encounter(true) and s.journey_phase == "event", "Insufficient funds do not consume the merchant event")
			s.gold = s.encounter_cost()
			var wisps = s.wisps
			check(s.resolve_encounter(true) and s.gold == 0 and s.wisps == wisps + 1, "Merchant charges the quoted cost exactly once")
		elif kind == "altar":
			s.hp = s.encounter_cost()
			check(not s.resolve_encounter(true) and not s.dead, "Altar cannot kill the player")
			s.hp = s.max_hp()
			var damage = s.auto_damage()
			var click = s.click_damage()
			var cost = s.encounter_cost()
			check(s.resolve_encounter(true) and s.hp == s.max_hp() - cost and is_equal_approx(s.auto_damage(), damage * 1.2) and is_equal_approx(s.click_damage(), click * 1.2), "Altar trades health for both damage sources")
			check(s.save_game(SAVE) and restored.load_game(SAVE, false) and restored.altar_pacts == 1, "The altar pact persists through reload")
		else:
			s.hp = s.max_hp() - 1
			check(s.resolve_encounter(true) and s.hp == s.max_hp(), "Sanctuary never heals above maximum health")
		check(not s.resolve_encounter(true) and s.active(), "Resolved event cannot be claimed twice: " + kind)
		s.restart()
		check(s.altar_pacts == 0 and s.journey_phase.is_empty() and s.wisps == 1, "Rebirth resets event bonuses and supplies one companion")
	s = milestone()
	s.choose_relic(s.offers[0])
	s.choose_route(2)
	var money = s.gold
	check(s.resolve_encounter(false) and s.gold == money and s.active(), "Any encounter can be declined without payment")
	# A real previous-format snapshot must migrate without erasing progress.
	var old = s.snapshot()
	old.version = 2
	for key in ["journey_phase", "encounter_kind", "altar_pacts"]:
		old.erase(key)
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(restored.load_game(SAVE, false) and restored.room == s.room and restored.wisps == s.wisps and restored.journey_phase.is_empty(), "Version 2 migrates without inventing a pending route or losing companions")
	s.restart()
	s.spawn_delay = 0
	check(s.auto_damage() == 4 and s.wisps == 1, "Companion support exists before the first purchase")
	var enemy_health = s.enemy_hp
	s.tick(1.0)
	check(s.enemy_hp < enemy_health, "The opening fight progresses without clicking")
	s.idle_time = 3
	s.damage_enemy(1, false, true)
	check(s.idle_time == 0, "Companion hits prevent idle regeneration in the crypt")
	s.click_cooldown = 0
	check(s.click(), "Manual attack is available")
	s.tick(0.1)
	check(not s.click(), "Faster clicking cannot exceed the deliberate attack cadence")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	print("JOURNEY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
