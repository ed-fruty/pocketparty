extends Control
signal finished(scores: Dictionary)
const Avatar = preload("res://ui/avatar.gd")
const Audio = preload("res://core/audio.gd")
var game_id: String = "sprint"
var roster: Array = []
var scores: Dictionary = {}
var shown_steps: Dictionary = {}
var lamp_pop: float = 1.0
var pads: Dictionary = {}
var feedback: Dictionary = {}
var bot_clock: Dictionary = {}
var time: float = 0.0
var countdown: float = 3.0
var duration: float = 18.0
var ended: bool = false
var paused: bool = false
var signal_round: int = 0
var signal_phase: String = "wait"
var signal_clock: float = 0.0
var wait_target: float = 0.0
var reacted: Dictionary = {}
var bot_delay: Dictionary = {}
var badges: Dictionary = {}
var runners: Dictionary = {}
var audio: Node
var rng = RandomNumberGenerator.new()
var finger_press_times: Dictionary = {}
var finger_amounts: Dictionary = {}
var finger_tweens: Dictionary = {}
var held_corner_touches: Dictionary = {}
var last_native_touch: int = -1000

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		scores[p.id] = 0
		shown_steps[p.id] = 0.0
		feedback[p.id] = ""
		bot_clock[p.id] = 0.0
		var badge = Avatar.new()
		badge.tint = p.color
		badge.skin = p.skin
		add_child(badge)
		badges[p.id] = badge
		var runner = Avatar.new()
		runner.tint = p.color
		runner.skin = p.skin
		add_child(runner)
		runners[p.id] = runner
	new_signal()

func new_signal() -> void:
	signal_phase = "wait"
	signal_clock = 0.0
	wait_target = rng.randf_range(1.5, 3.3)
	reacted.clear()
	for p in roster:
		feedback[p.id] = ""
		bot_delay[p.id] = rng.randf_range(0.23, 0.65) * [1.6, 1.0, 0.65][Party.difficulty]

func _process(delta: float) -> void:
	if NetPlay.client_frame(self, delta):
		return
	if paused or ended:
		return
	if countdown > 0:
		countdown -= delta
		queue_redraw()
		return
	time += delta
	for p in roster:
		shown_steps[p.id] = lerpf(shown_steps[p.id], float(scores[p.id]), 1.0 - exp(-delta * 16.0))
	lamp_pop = lerpf(lamp_pop, 1.0, 1.0 - exp(-delta * 10.0))
	if game_id == "sprint":
		for p in roster:
			if p.bot:
				bot_clock[p.id] += delta
				var interval: float = [0.40, 0.27, 0.18][Party.difficulty]
				if bot_clock[p.id] >= interval:
					bot_clock[p.id] = rng.randf_range(-0.08, 0.04)
					activate(p.id)
		if time >= duration or scores.values().max() >= 80:
			complete()
	else:
		signal_clock += delta
		if signal_phase == "wait" and signal_clock >= wait_target:
			signal_phase = "go"
			lamp_pop = 1.18
			signal_clock = 0
			audio.tone(880)
		if signal_phase == "go":
			for p in roster:
				if p.bot and not reacted.has(p.id) and signal_clock >= bot_delay[p.id]:
					activate(p.id)
			if signal_clock >= 1.5:
				signal_phase = "review"
				signal_clock = 0
		if signal_phase == "review" and signal_clock >= 1.2:
			signal_round += 1
			if signal_round >= 5:
				complete()
			else:
				new_signal()
	queue_redraw()

func activate(id: int) -> void:
	if NetPlay.intercept(id, "tap"):
		return
	if ended or paused or countdown > 0 or not scores.has(id):
		return
	if game_id == "sprint":
		# Cap accepted input to 12 presses/sec, preventing key-repeat or event spam.
		if time - float(feedback.get("last_%d" % id, -1.0)) < 0.083:
			return
		feedback["last_%d" % id] = time
		scores[id] += 1
		audio.tone(420 + id * 110)
	else:
		if reacted.has(id) or signal_phase == "review":
			return
		reacted[id] = true
		if signal_phase == "wait":
			scores[id] = maxi(0, int(scores[id]) - 100)
			feedback[id] = "Too soon! -100"
			audio.tone(180)
		else:
			var points: int = maxi(50, 1000 - int(signal_clock * 600))
			scores[id] += points
			feedback[id] = "%d ms  +%d" % [int(signal_clock * 1000), points]
			audio.tone(600 + id * 110)
	queue_redraw()

func complete() -> void:
	if NetPlay.active and not NetPlay.hosting:
		return
	if ended:
		return
	ended = true
	finished.emit(scores.duplicate())

func _input(event: InputEvent) -> void:
	if game_id == "pairs" or ended or paused or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		last_native_touch = Time.get_ticks_msec()
		if event.pressed:
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			var id: int = corner_at(local_pos)
			if id >= 0:
				held_corner_touches[event.index] = id
				press_corner(id)
				get_viewport().set_input_as_handled()
		elif held_corner_touches.has(event.index):
			var released_id: int = held_corner_touches[event.index]
			held_corner_touches.erase(event.index)
			release_finger(released_id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() - last_native_touch < 100:
			return
		if event.pressed:
			var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			var id: int = corner_at(local_pos)
			if id >= 0:
				held_corner_touches[-1] = id
				press_corner(id)
				get_viewport().set_input_as_handled()
		elif held_corner_touches.has(-1):
			var released_id: int = held_corner_touches[-1]
			held_corner_touches.erase(-1)
			release_finger(released_id)
			get_viewport().set_input_as_handled()

func corner_at(local_pos: Vector2) -> int:
	for p in roster:
		if not p.bot and NetPlay.can_control(p.id) and pads.has(p.id) and pads[p.id].has_point(local_pos):
			return p.id
	return -1

func press_corner(id: int) -> void:
	if not NetPlay.dispatching and not NetPlay.can_control(id):
		return
	finger_press_times[id] = Time.get_ticks_msec()
	animate_finger(id, true)
	activate(id)
	queue_redraw()

func animate_finger(id: int, down: bool) -> void:
	if finger_tweens.has(id) and is_instance_valid(finger_tweens[id]):
		finger_tweens[id].kill()
	var motion = create_tween()
	finger_tweens[id] = motion
	motion.set_trans(Tween.TRANS_CUBIC if down else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_method(func(value: float):
		finger_amounts[id] = value
		queue_redraw(), float(finger_amounts.get(id, 0.0)), 1.0 if down else 0.0, 0.09 if down else 0.24)
	if down:
		motion.tween_callback(func():
			if not held_corner_touches.values().has(id):
				animate_finger(id, false))

func release_finger(id: int) -> void:
	if held_corner_touches.values().has(id):
		return
	# Let even a very quick tap finish the soft downward motion first.
	if Time.get_ticks_msec() - int(finger_press_times.get(id, 0)) >= 90:
		animate_finger(id, false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		press_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_at(event.position)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_A, KEY_L, KEY_Z, KEY_M].find(event.physical_keycode)
		if index >= 0:
			for p in roster:
				if p.id == index and not p.bot:
					activate(index)

func press_at(pos: Vector2) -> void:
	for p in roster:
		if not p.bot and NetPlay.can_control(p.id) and pads.has(p.id) and pads[p.id].has_point(pos):
			press_corner(p.id)
			return

func style(color: Color, radius: int = 24) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

func text_at(value: String, center: Vector2, font_size: int, color: Color = Color("f4f1ff")) -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, center - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var arena_height: float = size.y - 220
	draw_style_box(style(Color("151e34")), Rect2(0, 110, size.x, arena_height))
	if game_id == "sprint":
		round_clock("%02d seconds" % maxi(0, ceili(duration - time)))
		var target: float = 80.0
		for p in roster:
			var lane: Rect2 = player_field(p.id)
			draw_player_field(lane, p.id)
			var y: float = lane.get_center().y
			text_at("P%d%s" % [p.id + 1, " · BOT" if p.bot else ""], Vector2(lane.get_center().x, lane.position.y + 28), 18, p.color)
			draw_line(Vector2(lane.position.x + 22, y), Vector2(lane.end.x - 22, y), Color("29344b"), 3)
			for x in range(5):
				draw_line(Vector2(lane.end.x - 43 + (x % 2) * 7, y - 18 + x * 7), Vector2(lane.end.x - 36 + (x % 2) * 7, y - 18 + x * 7), Color("f4f1ff"), 5)
			var pos = Vector2(lane.position.x + 42 + (lane.size.x - 115) * minf(float(shown_steps[p.id]) / target, 1), y)
			runners[p.id].size = Vector2(64, 64)
			runners[p.id].position = pos - Vector2(32, 32)
			runners[p.id].visible = countdown <= 0
			text_at(str(scores[p.id]), Vector2(pos.x, y + 40), 16, p.color)
	else:
		var green: bool = signal_phase == "go"
		var c = Vector2(size.x / 2, size.y / 2)
		circle(c, minf(size.x * 0.2, arena_height * 0.35) * lamp_pop, Color("6ce5bc") if green else Color("ffb276") if signal_phase == "wait" else Color("b3a0ff"))
		text_at("TAP!" if green else "WAIT" if signal_phase == "wait" else "NICE!", c + Vector2(0, 12), 30, Color("11182b"))
		round_clock("Signal %d / 5" % (signal_round + 1))
		text_at("Green means go. Orange means wait.", Vector2(size.x / 2, size.y - 80), 18, Color("302245"))
	for p in roster:
		badges[p.id].hide()
		if game_id != "sprint":
			runners[p.id].hide()
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.93)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size * 0.5, 100, Color("ffd577"))
		text_at("Get ready · your color is your control", size * 0.5 + Vector2(0, 65), 21)

func circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color, true, -1, true)

func control_is_highlighted(_id: int) -> bool:
	return true

func control_label(id: int, bot: bool) -> String:
	return "P%d · %s" % [id + 1, "BOT" if bot else "FRIEND" if not NetPlay.can_control(id) else "YOU · TAP" if NetPlay.active else "TAP"]

func corner_controls(interactive: bool = true) -> void:
	pads.clear()
	var control_size = Vector2(112, 132)
	for id in range(4):
		var p: Dictionary = {}
		for player in roster:
			if player.id == id:
				p = player
		if p.is_empty():
			continue
		var corner_pos = Vector2(8 if id % 2 == 0 else size.x - control_size.x - 8, size.y - control_size.y - 8 if id < 2 else 8)
		if size.y > size.x and roster.size() <= 2:
			# Keep small portrait groups within easy thumb reach, regardless of seat IDs.
			var seat_index: int = roster.find(p)
			corner_pos.y = size.y - control_size.y - 8
			corner_pos.x = (size.x - control_size.x) * 0.5 if roster.size() == 1 else (8.0 if seat_index == 0 else size.x - control_size.x - 8)
		var rect = Rect2(corner_pos, control_size)
		var highlighted: bool = control_is_highlighted(id)
		var color: Color = Party.COLORS[id] if highlighted else Party.COLORS[id].darkened(0.65)
		var active: bool = not p.is_empty()
		if interactive and active:
			pads[id] = rect
		draw_style_box(style(Color("121b2b") if p.bot else Color("17243c"), 24), rect)
		draw_arc(rect.get_center() - Vector2(0, 15), 33, 0, TAU, 40, color if active else color.darkened(0.5), 5, true)
		var press_amount: float = float(finger_amounts.get(id, 0.0))
		var hand = rect.get_center() - Vector2(0, 10) + Vector2(0, press_amount * 6)
		if highlighted and not p.bot:
			var glow: Color = color
			glow.a = 0.55 + sin(Time.get_ticks_msec() * 0.004) * 0.2
			draw_arc(rect.get_center() - Vector2(0, 15), 38, 0, TAU, 40, glow, 2, true)
		if p.bot:
			draw_robot_control(hand)
			text_at("P%d" % (id + 1), rect.position + Vector2(83, 25), 16, Party.COLORS[id])
		else:
			draw_finger(hand, 1.0 - press_amount * 0.14, Color.WHITE if highlighted and NetPlay.can_control(id) else Color("657087"))
		if press_amount > 0.03:
			var flash: Color = color
			flash.a = clampf(press_amount, 0, 1)
			draw_arc(rect.get_center() - Vector2(0, 15), 38 + (1.0 - press_amount) * 8, 0, TAU, 40, flash, 3, true)
		circle(rect.position + Vector2(20, 20), 8, color)
		text_at("BOT" if p.bot else control_label(id, false), rect.get_center() + Vector2(0, 38), 24 if p.bot else 15, Color("a4afc8") if p.bot else color)
		if active:
			text_at(str(scores.get(id, 0)) + (" cm" if game_id == "burger" else ""), rect.get_center() + Vector2(0, 59), 22, Color.WHITE)

func draw_robot_control(center: Vector2) -> void:
	var ink = Color("8794aa")
	draw_style_box(style(ink, 8), Rect2(center - Vector2(25, 18), Vector2(50, 36)))
	draw_line(center - Vector2(0, 18), center - Vector2(0, 27), ink, 3, true)
	circle(center - Vector2(0, 29), 4, ink)
	for side in [-1, 1]:
		circle(center + Vector2(side * 11, -3), 5, Color("121b2b"))
		draw_line(center + Vector2(side * 30, -6), center + Vector2(side * 30, 8), ink, 5, true)
	draw_line(center + Vector2(-9, 10), center + Vector2(9, 10), Color("121b2b"), 3, true)

func draw_finger(center: Vector2, scale_factor: float, color: Color) -> void:
	draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	draw_style_box(style(color, 9), Rect2(-14, -6, 32, 30))
	draw_line(Vector2(-9, -26), Vector2(-9, 7), color, 10, true)
	circle(Vector2(-9, -26), 5, color)
	draw_line(Vector2(-22, 2), Vector2(-12, 15), color, 10, true)
	circle(Vector2(-22, 2), 5, color)
	for x in [2, 10, 17]:
		circle(Vector2(x, -4), 5, color)
	draw_set_transform(Vector2.ZERO)

func round_clock(value: String) -> void:
	if NetPlay.active:
		var note: String = "Waiting for friends…" if NetPlay.waiting else "HOST PAUSED" if paused else "NetPlay · YOU ARE P%d" % (NetPlay.local_id + 1)
		text_at(note, Vector2(size.x / 2, size.y - 12), 16, Party.COLORS[maxi(0, NetPlay.local_id)])
	draw_style_box(style(Color("17243c"), 16), Rect2(size.x / 2 - 105, 8, 210, 40))
	text_at(value, Vector2(size.x / 2, 36), 24, Color("ffd15c"))

func player_field(id: int, top: float = 110, bottom: float = 110) -> Rect2:
	# Use the same bottom-first seating as the fingers: P3 P4 / P1 P2.
	var area = Rect2(8, top, maxf(1, size.x - 16), maxf(1, size.y - top - bottom))
	if roster.size() == 1:
		return area
	var column: int = id % 2
	var row: int = 1 if id < 2 else 0
	var columns: int = 2
	var rows: int = 2
	if roster.size() == 2:
		if size.y > size.x:
			rows = 1
			row = 0
			column = 0 if roster[0].id == id else 1
		elif roster[0].id % 2 != roster[1].id % 2:
			rows = 1
			row = 0
		else:
			columns = 1
			column = 0
	var cell = Vector2((area.size.x - (columns - 1) * 12) / columns, (area.size.y - (rows - 1) * 12) / rows)
	return Rect2(area.position + Vector2(column, row) * (cell + Vector2(12, 12)), cell)

func draw_player_field(rect: Rect2, id: int, fill: Color = Color("17243c")) -> void:
	var panel = style(fill, 18)
	panel.set_border_width_all(4)
	panel.border_color = Party.COLORS[id]
	draw_style_box(panel, rect)
