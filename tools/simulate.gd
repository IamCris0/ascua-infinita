extends SceneTree
## Balance probe: a simple bot plays several expeditions and reports how far it gets.
## godot --headless --path . --script tools/simulate.gd
const State = preload("res://scripts/run_state.gd")

func play(s, cps: float, buy_strategy: String, max_minutes: float) -> Dictionary:
	var dt = 0.05
	var click_every = 1.0 / cps
	var click_acc = 0.0
	var t = 0.0
	while not s.dead and t < max_minutes * 60:
		s.tick(dt)
		t += dt
		click_acc += dt
		if not s.offers.is_empty():
			s.choose_relic(s.offers[s.rng.randi_range(0, s.offers.size() - 1)])
		if s.ember_active and s.rng.randf() < 0.02:
			s.collect_ember()
		while click_acc >= click_every:
			click_acc -= click_every
			s.click()
		if s.burst_cooldown <= 0 and (not s.is_boss() or s.charging):
			s.burst()
		# Buy the cheapest useful upgrade; keep armour when health is low.
		var order = [0, 1, 2, 3]
		if buy_strategy == "balanced":
			order.sort_custom(func(a, b): return s.price(a) < s.price(b))
		if s.hp < s.max_hp() * 0.45:
			order.push_front(2)
		for k in order:
			if s.gold >= s.price(k):
				s.buy(k)
				break
	return {"room": s.room, "minutes": t / 60.0, "essence": s.run_essence}

func _initialize() -> void:
	for cps in [3.0, 5.0]:
		var s = State.new()
		s.rng.seed = 42
		var line = "cps %.0f:" % cps
		for run in range(12):
			s.restart()
			var r = play(s, cps, "balanced", 40)
			line += "  [#%d sala %d, %.1f min, +%d]" % [run + 1, r.room, r.minutes, r.essence]
			s.finish_run()
			# Spend ascuas on the cheapest permanent upgrade.
			var bought = true
			while bought:
				bought = false
				var best_k = -1
				for k in range(s.LEGACY.size()):
					if s.essence >= s.legacy_price(k) and (best_k < 0 or s.legacy_price(k) < s.legacy_price(best_k)):
						best_k = k
				if best_k >= 0:
					bought = s.buy_legacy(best_k)
		print(line)
	quit()
