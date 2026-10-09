extends SceneTree
## Balance probe: a simple bot plays several expeditions and reports how far it gets.
## godot --headless --path . --script tools/simulate.gd [-- --sample] [-- --lane=1 --seed=7 --no-arsenal]
const State = preload("res://scripts/run_state.gd")

## Share of parries and weak points a player at this cadence lands: an idle
## player never guards or aims; a busy one usually does.
func skill_for(cps: float) -> float:
	return clampf(cps * 0.18, 0.0, 0.85)

func play(s, cps: float, buy_strategy: String, max_minutes: float, lane_choice: int = 0) -> Dictionary:
	var dt = 0.05
	var click_every = 1.0 / cps if cps > 0 else INF
	var click_acc = 0.0
	var t = 0.0
	var skill = skill_for(cps)
	var guard_plan = ""
	while not s.dead and t < max_minutes * 60:
		s.tick(dt)
		t += dt
		click_acc += dt
		if not s.offers.is_empty():
			s.choose_relic(s.offers[s.rng.randi_range(0, s.offers.size() - 1)])
		# The bot keeps to the safe lane and takes the free or useful deals.
		if s.journey_phase == "map" and s.offers.is_empty():
			s.choose_lane(lane_choice)
		if s.journey_phase == "chest":
			s.open_chest()
		if s.journey_phase == "event":
			s.resolve_encounter(s.can_accept_encounter() and s.encounter_kind in ["shrine", "merchant"])
		if s.ember_active and s.rng.randf() < 0.02:
			s.collect_ember()
		# Active play: each blow is met with a perfect parry, a block or nothing,
		# and lit weak points are aimed at.
		var blow = s.blow_in()
		if blow < 0 or blow > s.PARRY_WINDOW:
			guard_plan = ""
		elif guard_plan.is_empty():
			var roll = s.rng.randf()
			guard_plan = "perfect" if roll < skill * 0.6 else ("block" if roll < skill else "none")
		if guard_plan == "block" and s.can_parry():
			s.parry()
			guard_plan = "done"
		elif guard_plan == "perfect" and blow <= s.PARRY_PERFECT - 0.05 and s.can_parry():
			s.parry()
			guard_plan = "done"
		if s.weak_active and s.click_cooldown <= 0 and s.rng.randf() < skill * 0.1:
			s.strike_weak()
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

## Buys the cheapest available node until nothing is affordable, then swears
## the oath of the branch with most levels invested. With a focus branch the
## bot only buys that branch and the shared row, and saves for its oath once
## it is unlocked.
func spend_legacy(s, focus: String = "") -> void:
	var focus_oath = -1
	for k in range(s.LEGACY.size()):
		if s.is_oath(k) and s.LEGACY[k].branch == focus:
			focus_oath = k
	while true:
		if focus_oath >= 0 and s.legacy_level(focus_oath) == 0 and s.legacy_unlocked(focus_oath):
			if not s.buy_legacy(focus_oath):
				break
			continue
		var best_k = -1
		for k in range(s.LEGACY.size()):
			if not s.can_buy_legacy(k):
				continue
			if not focus.is_empty() and not s.LEGACY[k].branch in [focus, ""]:
				continue
			if best_k < 0 or s.legacy_price(k) < s.legacy_price(best_k):
				best_k = k
		if best_k < 0 or not s.buy_legacy(best_k):
			break
	var invested = {}
	for k in range(s.LEGACY.size()):
		var branch: String = s.LEGACY[k].branch
		invested[branch] = invested.get(branch, 0) + s.legacy_level(k)
	var best_oath = -1
	for k in range(s.LEGACY.size()):
		if s.is_oath(k) and s.legacy_level(k) > 0 and (best_oath < 0 or k == focus_oath or invested[s.LEGACY[k].branch] > invested[s.LEGACY[best_oath].branch]):
			if best_oath != focus_oath or best_oath < 0:
				best_oath = k
	if best_oath >= 0:
		s.set_oath(best_oath)

## Equips the strongest piece of each slot, salvages the rest, then spends the
## esquirlas on the cheapest upgrade or mastery until nothing is affordable.
func manage_arsenal(s) -> void:
	for slot in s.SLOTS:
		var best := {}
		for item in s.armory:
			if s.ITEMS[item.base].slot != slot:
				continue
			if best.is_empty() or s.item_value(item) / s.ITEMS[item.base].base > s.item_value(best) / s.ITEMS[best.base].base:
				best = item
		if not best.is_empty():
			s.equip(best.uid)
	for item in s.armory.duplicate():
		if not s.is_equipped(item.uid):
			s.salvage(item.uid)
	while true:
		var cost = INF
		var action = Callable()
		for slot in s.SLOTS:
			var item = s.equipped_item(slot)
			if not item.is_empty() and item.level < s.max_item_level(item) and s.upgrade_cost(item) < cost:
				cost = s.upgrade_cost(item)
				action = s.upgrade_item.bind(item.uid)
		for i in range(s.MASTERIES.size()):
			if s.mastery(s.MASTERIES[i].id) < s.MASTERIES[i].max and s.mastery_cost(i) < cost:
				cost = s.mastery_cost(i)
				action = s.buy_mastery.bind(i)
		if not action.is_valid() or cost > s.scrap or not action.call():
			break

func _initialize() -> void:
	# --lane=N keeps the bot on one lane of the map (0 safe, 1 risk, 2 chance).
	var lane_choice = 0
	var seed_value = 42
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lane="):
			lane_choice = int(arg.substr(7))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
	if "--sample" in OS.get_cmdline_user_args():
		for cps in [0.0, 1.0, 3.0, 5.0]:
			var rooms: Array = []
			var minutes = 0.0
			for sample_seed in [7, 19, 42, 73, 101]:
				var sample = State.new()
				sample.rng.seed = sample_seed
				sample.restart()
				var result = play(sample, cps, "balanced", 40, lane_choice)
				rooms.append(result.room)
				minutes += result.minutes
			print("SAMPLE cps %.0f: rooms %s, mean minutes %.2f" % [cps, rooms, minutes / 5])
		quit()
		return
	for cps in [0.0, 1.0, 3.0, 5.0]:
		var s = State.new()
		s.rng.seed = seed_value
		var line = "cps %.0f:" % cps
		for run in range(12):
			s.restart()
			var r = play(s, cps, "balanced", 40, lane_choice)
			line += "  [#%d sala %d, %.1f min, +%d]" % [run + 1, r.room, r.minutes, r.essence]
			s.finish_run()
			spend_legacy(s)
			if not "--no-arsenal" in OS.get_cmdline_user_args():
				manage_arsenal(s)
		print(line)
	quit()
