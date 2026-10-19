extends "res://games/arena.gd"
const JUMP_SECONDS: float = 0.9
const DUCK_SECONDS: float = 0.85
var alive: Dictionary = {}
var jump_starts: Dictionary = {}
var duck_ends: Dictionary = {}
var duck_blends: Dictionary = {}
var death_times: Dictionary = {}
var action_pads: Dictionary = {}
var pending_actions: Dictionary = {}
var course: Array = []
var finishing: float = -1.0

func _ready() -> void:
	game_id = "obby"
	duration = 35.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		alive[p.id] = true
		scores[p.id] = 0
		jump_starts[p.id] = -10.0
		duck_ends[p.id] = -10.0
		duck_blends[p.id] = 0.0
		death_times[p.id] = -10.0
		var runner = Avatar.new()
		runner.tint = p.color
		runner.skin = p.skin
		add_child(runner)
		runners[p.id] = runner
	var next: float = 2.3
	while next < duration - 0.7:
		var kind: String = "jump" if rng.randf() < 0.5 else "duck"
		var plans: Dictionary = {}
		for p in roster:
			plans[p.id] = {"done": false, "correct": rng.randf() < [0.70, 0.86, 0.96][Party.difficulty]}
		course.append({"at": next, "kind": kind, "checked": false, "plans": plans})
		next += rng.randf_range(1.45, 1.85)

func living_ids() -> Array:
	var ids: Array = []
	for id in alive:
		if alive[id]:
			ids.append(id)
	return ids

func jump_height(id: int, at: float) -> float:
	var progress: float = (at - float(jump_starts[id])) / JUMP_SECONDS
	return 360.0 * progress * (1.0 - progress) if progress > 0 and progress < 1 else 0.0

func do_action(id: int, action: String, at: float = -1.0) -> void:
	if NetPlay.intercept(id, "obstacle", action):
		return
	if paused or ended or countdown > 0 or finishing >= 0 or not alive.get(id, false):
		return
	if at < 0:
		at = time
	var jumping: bool = at >= jump_starts[id] and at < float(jump_starts[id]) + JUMP_SECONDS
	if action == "jump" and not jumping and at >= duck_ends[id]:
		jump_starts[id] = at
		audio.tone(560 + id * 60)
	elif action == "duck" and not jumping:
		duck_ends[id] = at + DUCK_SECONDS
		audio.tone(320 + id * 50)
	queue_redraw()

func activate(id: int) -> void:
	do_action(id, pending_actions.get(id, "jump"))

func _process(delta: float) -> void:
	if NetPlay.client_frame(self, delta):
		return
	if paused or ended:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - delta)
	elif finishing >= 0:
		finishing += delta
		if finishing >= 0.8:
			complete()
	else:
		time = minf(duration, time + delta)
		for obstacle in course:
			for p in roster:
				var plan: Dictionary = obstacle.plans[p.id]
				if p.bot and alive[p.id] and not plan.done and time >= obstacle.at - 0.34:
					plan.done = true
					var action: String = obstacle.kind if plan.correct else ("duck" if obstacle.kind == "jump" else "jump")
					do_action(p.id, action, obstacle.at - 0.34)
			if not obstacle.checked and time >= obstacle.at:
				obstacle.checked = true
				resolve_obstacle(obstacle)
				if finishing >= 0:
					break
		for id in alive:
			if alive[id]:
				scores[id] = floori(time * 10) + (1 if finishing >= 0 else 0)
		if time >= duration and finishing < 0:
			finishing = 0
	for id in alive:
		duck_blends[id] = lerpf(float(duck_blends[id]), 1.0 if time < duck_ends[id] else 0.0, 1.0 - exp(-delta * 18))
	queue_redraw()

func resolve_obstacle(obstacle: Dictionary) -> void:
	for p in roster:
		if not alive[p.id]:
			continue
		var safe: bool = jump_height(p.id, obstacle.at) >= 48.0 if obstacle.kind == "jump" else (duck_ends[p.id] > obstacle.at and jump_height(p.id, obstacle.at) <= 0)
		if not safe:
			alive[p.id] = false
			death_times[p.id] = time
			scores[p.id] = floori(obstacle.at * 10)
			audio.tone(180)
	if living_ids().is_empty() or (roster.size() > 1 and living_ids().size() == 1):
		finishing = 0

func corner_at(pos: Vector2) -> int:
	for p in roster:
		if p.bot or not NetPlay.can_control(p.id) or not alive[p.id] or not action_pads.has(p.id):
			continue
		for action in action_pads[p.id]:
			if action_pads[p.id][action].has_point(pos):
				pending_actions[p.id] = action
				return p.id
	return -1

func press_at(pos: Vector2) -> void:
	var id: int = corner_at(pos)
	if id >= 0:
		press_corner(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	for action in ["jump", "duck"]:
		var keys: Array = [KEY_A, KEY_L, KEY_Z, KEY_M] if action == "jump" else [KEY_S, KEY_K, KEY_X, KEY_N]
		var id: int = keys.find(event.physical_keycode)
		for p in roster:
			if p.id == id and not p.bot:
				do_action(id, action)

func corner_controls(_interactive: bool = true) -> void:
	pads.clear()
	action_pads.clear()
	var control_size = Vector2(168, 132)
	for p in roster:
		var pos = Vector2(8 if p.id % 2 == 0 else size.x - 176, size.y - 140 if p.id < 2 else 8)
		if size.y > size.x and roster.size() == 1:
			pos.x = (size.x - control_size.x) / 2
		elif size.y > size.x and roster.size() == 2:
			pos.x = 8 if roster.find(p) == 0 else size.x - 176
			pos.y = size.y - 140
		var rect = Rect2(pos, control_size)
		pads[p.id] = rect
		draw_style_box(style(Color("121b2b"), 18), rect)
		var color: Color = p.color if alive[p.id] else Color("657087")
		text_at("P%d · %s" % [p.id + 1, "OUT" if not alive[p.id] else "BOT" if p.bot else ("FRIEND" if not NetPlay.can_control(p.id) else "YOU" if NetPlay.active else "RUN!")], pos + Vector2(68, 25), 17, color)
		if p.bot:
			draw_robot_control(pos + Vector2(84, 74))
			text_at("AUTO" if alive[p.id] else "OUT", pos + Vector2(84, 120), 18, Color("8794aa"))
			continue
		draw_finger(pos + Vector2(143, 22), 0.4, Color.WHITE if alive[p.id] else Color("657087"))
		action_pads[p.id] = {}
		for i in range(2):
			var action: String = "jump" if i == 0 else "duck"
			var button_rect = Rect2(pos + Vector2(6 + i * 80, 36), Vector2(76, 88))
			action_pads[p.id][action] = button_rect
			var pressing: float = float(finger_amounts.get(p.id, 0)) if pending_actions.get(p.id, "") == action else 0.0
			var drawn = button_rect.grow(-pressing * 3)
			drawn.position.y += pressing * 3
			draw_style_box(style(color.darkened(0.65) if alive[p.id] else Color("20283a"), 12), drawn)
			text_at("↑" if i == 0 else "↓", drawn.get_center() - Vector2(0, 5), 33, Color.WHITE if alive[p.id] and NetPlay.can_control(p.id) else color)
			text_at(action.to_upper(), drawn.get_center() + Vector2(0, 27), 14, Color.WHITE if alive[p.id] and NetPlay.can_control(p.id) else color)

func _draw() -> void:
	var live: Array = living_ids()
	round_clock("FINISH!" if finishing >= 0 and not live.is_empty() else "%ds · %d left" % [maxi(0, ceili(duration - time)), live.size()])
	for i in range(roster.size()):
		var p: Dictionary = roster[i]
		var lane: Rect2 = player_field(p.id, 156, 156)
		var lane_height: float = lane.size.y
		draw_player_field(lane, p.id, Color("182941") if alive[p.id] else Color("202535"))
		var ground: float = lane.end.y - 14
		var runner_x: float = lane.position.x + lane.size.x * 0.2
		var body_height: float = clampf(lane_height * 0.5, 30, 60)
		var hop: float = jump_height(p.id, time) / 90 * minf(56, lane_height * 0.35)
		var crouch: float = 1 - float(duck_blends[p.id]) * 0.56
		var color: Color = p.color if alive[p.id] else Color("657087")
		text_at("P%d%s · %dm" % [p.id + 1, " BOT" if p.bot else "", scores[p.id]], lane.position + Vector2(lane.size.x * 0.55, 21), 16, color)
		draw_line(Vector2(lane.position.x + 8, ground), Vector2(lane.end.x - 8, ground), Color("536785"), 3, true)
		for mark in range(12):
			var x: float = lane.position.x + fposmod(mark * lane.size.x / 12 - time * 90, lane.size.x)
			draw_line(Vector2(x, ground + 6), Vector2(x + 10, ground + 6), Color("405069"), 2, true)
		for obstacle in course:
			var x: float = runner_x + (obstacle.at - time) * lane.size.x / 2.7
			if x < lane.position.x + 12 or x > lane.end.x - 24:
				continue
			if obstacle.kind == "jump":
				draw_style_box(style(Color("ffb276"), 5), Rect2(x - 12, ground - body_height * 0.38, 24, body_height * 0.38))
				text_at("↑", Vector2(x, ground - body_height * 0.38 - 7), 19, Color("ffb276"))
			else:
				draw_style_box(style(Color("f6d36f"), 5), Rect2(x - 14, ground - body_height, 28, body_height * 0.48))
				text_at("↓", Vector2(x, ground - body_height - 7), 19, Color("f6d36f"))
		var death: float = clampf((time - float(death_times[p.id]) + maxf(0, finishing)) * 4, 0, 1) if not alive[p.id] else 0
		var foot = Vector2(runner_x, ground - hop + death * 6)
		draw_set_transform(foot, death * 0.8, Vector2(1, crouch))
		draw_style_box(style(color, 5), Rect2(-8, -body_height * 0.65, 16, body_height * 0.4))
		var stride: float = sin(time * 16) * 7 if alive[p.id] else 0.0
		for side in [-1, 1]:
			draw_line(Vector2(side * 5, -body_height * 0.25), Vector2(side * stride, 0), color, 5, true)
		draw_set_transform(Vector2.ZERO)
		var avatar_size: float = body_height * 0.85
		var runner: Control = runners[p.id]
		runner.size = Vector2.ONE * avatar_size
		runner.scale = Vector2(1, crouch)
		runner.position = foot - Vector2(avatar_size / 2, (body_height * 0.72 + avatar_size / 2) * crouch)
		runner.modulate.a = 0.45 if not alive[p.id] else 1.0
		if not alive[p.id]:
			text_at("OUT!", Vector2(lane.end.x - 54, ground - 14), 24, Color("ffb276"))
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at("↑ JUMP over blocks · ↓ DUCK under bars", size / 2 + Vector2(0, 60), 22)
