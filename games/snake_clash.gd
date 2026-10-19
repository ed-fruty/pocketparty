extends "res://games/arena.gd"
const STEP: float = 0.04
const SPEED: float = 175.0
const WORLD: float = 1000.0
const INITIAL_LENGTH: int = 8
var bodies: Dictionary = {}
var previous_bodies: Dictionary = {}
var headings: Dictionary = {}
var wishes: Dictionary = {}
var alive: Dictionary = {}
var sticks: Dictionary = {}
var foods: Array = []
var eaten_at: Dictionary = {}
var notices: Dictionary = {}
var notice_times: Dictionary = {}
var bot_thinks: Dictionary = {}
var accumulator: float = 0.0
var chase_leader: int = -1
var chase_left: float = 10.0
var hunt_active: bool = false

func _ready() -> void:
	game_id = "snake"
	duration = 10.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		var start = Vector2(210 if p.id % 2 == 0 else 790, 790 if p.id < 2 else 210)
		var direction: Vector2 = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN][p.id]
		bodies[p.id] = []
		for i in range(INITIAL_LENGTH):
			bodies[p.id].append(start - direction * SPEED * STEP * i)
		previous_bodies[p.id] = bodies[p.id].duplicate()
		headings[p.id] = direction
		wishes[p.id] = direction
		alive[p.id] = true
		sticks[p.id] = Vector2.ZERO
		scores[p.id] = INITIAL_LENGTH
		eaten_at[p.id] = -10.0
		notices[p.id] = ""
		notice_times[p.id] = -10.0
		bot_thinks[p.id] = 0.0
		foods.append(start + direction * 95)
	while foods.size() < 18:
		spawn_pizza()

func field_rect() -> Rect2:
	return Rect2(16, 156, maxf(1, size.x - 32), maxf(1, size.y - 312))

func world_to_screen(point: Vector2) -> Vector2:
	var field = field_rect()
	return field.position + point / WORLD * field.size

func spawn_pizza() -> void:
	var point = Vector2(500, 500)
	for attempt in range(80):
		point = Vector2(rng.randf_range(65, 935), rng.randf_range(65, 935))
		var clear: bool = true
		for food in foods:
			if point.distance_to(food) < 55:
				clear = false
		for id in bodies:
			if alive[id]:
				for segment in bodies[id]:
					if point.distance_to(segment) < 45:
						clear = false
		if clear:
			break
	foods.append(point)

func living_ids() -> Array:
	var ids: Array = []
	for id in alive:
		if alive[id]:
			ids.append(id)
	return ids

func grow(id: int, amount: int) -> void:
	for i in range(amount):
		bodies[id].append(bodies[id].back())
	scores[id] = bodies[id].size()

func _process(delta: float) -> void:
	if NetPlay.client_frame(self, delta):
		return
	if paused or ended:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - delta)
		queue_redraw()
		return
	accumulator += delta
	while accumulator >= STEP and not ended:
		accumulator -= STEP
		simulate_step(STEP)
	queue_redraw()

func simulate_step(delta: float) -> void:
	if ended or paused:
		return
	previous_bodies = bodies.duplicate(true)
	time += delta
	for p in roster:
		var id: int = p.id
		if not alive[id]:
			continue
		if p.bot:
			bot_thinks[id] -= delta
			if bot_thinks[id] <= 0:
				bot_thinks[id] = [0.30, 0.18, 0.10][Party.difficulty]
				think_bot(id)
		var angle: float = rotate_toward(headings[id].angle(), wishes[id].angle(), delta * 5.5)
		headings[id] = Vector2.from_angle(angle)
		var next: Vector2 = bodies[id][0] + headings[id] * SPEED * delta
		if next.x < 22 or next.x > WORLD - 22:
			headings[id].x *= -1
			wishes[id] = headings[id]
		if next.y < 22 or next.y > WORLD - 22:
			headings[id].y *= -1
			wishes[id] = headings[id]
		next.x = clampf(next.x, 22, WORLD - 22)
		next.y = clampf(next.y, 22, WORLD - 22)
		bodies[id].push_front(next)
		bodies[id].pop_back()
		for i in range(foods.size() - 1, -1, -1):
			if world_to_screen(next).distance_to(world_to_screen(foods[i])) <= snake_radius() * 2.0:
				foods.remove_at(i)
				grow(id, 3)
				notices[id] = "+3 · PIZZA!"
				notice_times[id] = time
				audio.tone(720 + id * 70)
				spawn_pizza()
	resolve_clashes()
	update_hunt(delta)

func unique_leader() -> int:
	var best: int = INITIAL_LENGTH
	var leader: int = -1
	var tied: bool = false
	for id in living_ids():
		var length: int = bodies[id].size()
		if length > best:
			best = length
			leader = id
			tied = false
		elif length == best:
			tied = true
	return -1 if tied else leader

func update_hunt(delta: float) -> void:
	var leader: int = unique_leader()
	hunt_active = leader >= 0
	if leader < 0:
		return # A tie pauses the hunt until one snake is biggest again.
	if leader != chase_leader:
		chase_leader = leader
		chase_left = 10.0
		notices[leader] = "BIGGEST! · 10s HUNT"
		notice_times[leader] = time
	else:
		chase_left = maxf(0, chase_left - delta)
	if chase_left <= 0.000001:
		chase_left = 0
		complete()

func think_bot(id: int) -> void:
	var head: Vector2 = bodies[id][0]
	var target: Vector2 = head + headings[id] * 50
	var best: float = INF
	for food in foods:
		var distance: float = head.distance_squared_to(food)
		if distance < best:
			best = distance
			target = food
	for other in bodies:
		if other == id or not alive[other]:
			continue
		var distance: float = head.distance_to(bodies[other][0])
		if bodies[other].size() > bodies[id].size() and distance < 180:
			target = head + (head - bodies[other][0]).normalized() * 220
			break
		if bodies[id].size() > bodies[other].size() and distance < 150:
			target = bodies[other][0]
	wishes[id] = (target - head).normalized()
	if wishes[id].is_zero_approx():
		wishes[id] = headings[id]

func snake_radius() -> float:
	var field = field_rect()
	return clampf(minf(field.size.x, field.size.y) * 0.021, 7, 15)

func snakes_touch(a: int, b: int) -> bool:
	var reach: float = snake_radius() * (1.08 + 0.85)
	for point in bodies[b]:
		if world_to_screen(bodies[a][0]).distance_to(world_to_screen(point)) <= reach:
			return true
	for point in bodies[a]:
		if world_to_screen(bodies[b][0]).distance_to(world_to_screen(point)) <= reach:
			return true
	return false

func resolve_clashes() -> void:
	var ids: Array = living_ids()
	# Resolve bigger predators first so a consumed snake cannot eat another one.
	ids.sort_custom(func(a, b): return bodies[a].size() > bodies[b].size())
	var lengths: Dictionary = {}
	for id in ids:
		lengths[id] = bodies[id].size()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: int = ids[i]
			var b: int = ids[j]
			if not alive[a] or not alive[b] or not snakes_touch(a, b):
				continue
			if lengths[a] == lengths[b]:
				var away: Vector2 = (bodies[a][0] - bodies[b][0]).normalized()
				if away.is_zero_approx():
					away = Vector2.LEFT
				headings[a] = away
				headings[b] = -away
				wishes[a] = away
				wishes[b] = -away
				continue
			alive[b] = false
			eaten_at[b] = time
			scores[b] = 0
			grow(a, maxi(1, ceili(lengths[b] * 0.5)))
			notices[a] = "ATE P%d!" % (b + 1)
			notice_times[a] = time
			audio.tone(940)

func steer_at(id: int, pos: Vector2) -> void:
	if not pads.has(id) or not alive.get(id, false):
		return
	var offset: Vector2 = (pos - (pads[id].get_center() - Vector2(0, 12))).limit_length(32)
	sticks[id] = offset
	if offset.length() > 5:
		var field = field_rect()
		var direction: Vector2 = (offset / field.size).normalized()
		if not NetPlay.intercept(id, "steer", direction):
			wishes[id] = direction

func corner_at(pos: Vector2) -> int:
	var id: int = super.corner_at(pos)
	if id >= 0 and alive.get(id, false):
		steer_at(id, pos)
		return id
	return -1

func activate(_id: int) -> void:
	pass # The finger controls steering; movement is automatic.

func _input(event: InputEvent) -> void:
	super._input(event)
	if paused or ended:
		return
	if event is InputEventScreenDrag and held_corner_touches.has(event.index):
		steer_at(held_corner_touches[event.index], get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and held_corner_touches.has(-1):
		steer_at(held_corner_touches[-1], get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or ended or paused:
		return
	var keys: Array = [[KEY_W, KEY_D, KEY_S, KEY_A], [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT], [KEY_I, KEY_L, KEY_K, KEY_J], [KEY_T, KEY_H, KEY_G, KEY_F]]
	for p in roster:
		if not p.bot and alive[p.id]:
			var direction: int = keys[p.id].find(event.physical_keycode)
			if direction >= 0:
				var heading: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][direction]
				if not NetPlay.intercept(p.id, "steer", heading):
					wishes[p.id] = heading

func corner_controls(_interactive: bool = true) -> void:
	pads.clear()
	var control_size = Vector2(112, 132)
	for p in roster:
		var pos = Vector2(8 if p.id % 2 == 0 else size.x - 120, size.y - 140 if p.id < 2 else 8)
		if size.y > size.x and roster.size() <= 2:
			pos.y = size.y - 140
			pos.x = (size.x - 112) / 2 if roster.size() == 1 else (8.0 if roster.find(p) == 0 else size.x - 120)
		var rect = Rect2(pos, control_size)
		pads[p.id] = rect
		var color: Color = p.color if alive[p.id] else Color("657087")
		draw_style_box(style(Color("121b2b"), 22), rect)
		if p.bot:
			draw_robot_control(rect.get_center() - Vector2(0, 16))
			text_at("P%d" % (p.id + 1), pos + Vector2(83, 25), 16, color)
		else:
			var center: Vector2 = rect.get_center() - Vector2(0, 12)
			draw_arc(center, 35, 0, TAU, 40, color, 4, true)
			var offset: Vector2 = sticks[p.id] * 0.6 if held_corner_touches.values().has(p.id) else Vector2.ZERO
			var amount: float = float(finger_amounts.get(p.id, 0))
			draw_finger(center + offset + Vector2(0, amount * 4), 0.8 - amount * 0.08, Color.WHITE if alive[p.id] and NetPlay.can_control(p.id) else color)
		var caption: String = "EATEN" if not alive[p.id] else "BOT" if p.bot else "P%d · %s" % [p.id + 1, "FRIEND" if not NetPlay.can_control(p.id) else "YOU · DRAG" if NetPlay.active else "DRAG"]
		text_at(caption, rect.get_center() + Vector2(0, 38), 24 if p.bot and alive[p.id] else 14, color)
		text_at(str(scores[p.id]), rect.get_center() + Vector2(0, 60), 21, Color.WHITE if alive[p.id] and NetPlay.can_control(p.id) else color)
		circle(pos + Vector2(18, 18), 6, color)

func draw_pizza(center: Vector2, radius: float) -> void:
	var triangle = PackedVector2Array([center + Vector2(-radius, -radius * 0.7), center + Vector2(radius, -radius * 0.7), center + Vector2(0, radius)])
	draw_colored_polygon(triangle, Color("ffd36a"))
	draw_line(triangle[0], triangle[1], Color("d78a45"), maxf(3, radius * 0.32), true)
	circle(center + Vector2(-radius * 0.28, -radius * 0.25), radius * 0.19, Color("e35b5d"))
	circle(center + Vector2(radius * 0.24, -radius * 0.1), radius * 0.17, Color("e35b5d"))
	circle(center + Vector2(0, radius * 0.45), radius * 0.15, Color("e35b5d"))

func _draw() -> void:
	round_clock("P%d · %02ds" % [chase_leader + 1, ceili(chase_left)] if hunt_active else "GROW!" if chase_leader < 0 else "TIE · GROW!")
	var field = field_rect()
	draw_style_box(style(Color("173b3a"), 22), field)
	for row in range(10):
		for col in range(10):
			if (row + col) % 2 == 0:
				draw_rect(Rect2(field.position + field.size * Vector2(col, row) / 10, field.size / 10), Color(1, 1, 1, 0.025))
	text_at("BIGGEST SNAKE: P%d · HOLD THE LEAD!" % (chase_leader + 1) if hunt_active else "EAT PIZZA · BECOME THE BIGGEST TO START THE HUNT", Vector2(size.x / 2, 141), 16, Color("ffd577"))
	var radius: float = snake_radius()
	for food in foods:
		draw_pizza(world_to_screen(food), radius * (0.9 + sin(time * 3 + food.x) * 0.06))
	var leader_length: int = 0
	for id in living_ids():
		leader_length = maxi(leader_length, bodies[id].size())
	for p in roster:
		var id: int = p.id
		var alpha: float = 1.0 if alive[id] else maxf(0, 1 - (time - float(eaten_at[id])) * 3)
		if alpha <= 0:
			continue
		var color: Color = p.color
		color.a = alpha
		var points: Array = bodies[id]
		var old: Array = previous_bodies.get(id, points)
		var draw_points: Array = []
		for i in range(points.size()):
			var point: Vector2 = old[mini(i, old.size() - 1)].lerp(points[i], clampf(accumulator / STEP, 0, 1))
			draw_points.append(world_to_screen(point))
		for i in range(draw_points.size() - 1, -1, -1):
			circle(draw_points[i] + Vector2(0, 3), radius, Color(0, 0, 0, 0.16 * alpha))
			circle(draw_points[i], radius * (1.08 if i == 0 else 0.85), color)
		var head: Vector2 = draw_points[0]
		var forward: Vector2 = (headings[id] * field.size).normalized()
		var side: Vector2 = forward.orthogonal()
		for sign_value in [-1, 1]:
			var eye: Vector2 = head + forward * radius * 0.35 + side * radius * sign_value * 0.45
			circle(eye, radius * 0.29, Color.WHITE * Color(1, 1, 1, alpha))
			circle(eye + forward * radius * 0.09, radius * 0.13, Color("14253c"))
		draw_style_box(style(Color(0.07, 0.12, 0.19, alpha * 0.85), 8), Rect2(head - Vector2(34, radius + 27), Vector2(68, 22)))
		text_at("P%d · %d" % [id + 1, scores[id]], head - Vector2(0, radius + 11), 15, color)
		if alive[id] and bodies[id].size() == leader_length and leader_length > INITIAL_LENGTH:
			draw_arc(head, radius + 5, 0, TAU, 32, Color("ffd577"), 2, true)
		if time - float(notice_times[id]) < 0.8:
			text_at(notices[id], head + Vector2(0, radius + 25), 15, Color("ffd577"))
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at("Drag your finger to steer · eat pizza to grow", size / 2 + Vector2(0, 60), 22)
