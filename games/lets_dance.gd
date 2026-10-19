extends "res://games/arena.gd"
const MOVES: Array = ["WAVE", "JUMP", "SPIN", "CLAP"]
const SYMBOLS: Array = ["↔", "↑", "↻", "●"]
const MOVE_COLORS: Array = [Color("73c9ff"), Color("6ce5bc"), Color("b3a0ff"), Color("ffb276")]
const SEQUENCE_LENGTH: int = 5
const BEAT: float = 0.75
var leader_id: int = -1
var sequence: Array = []
var phase: String = "create"
var phase_time: float = 0.0
var watch_index: int = -1
var progress: Dictionary = {}
var failed: Dictionary = {}
var poses: Dictionary = {}
var pose_times: Dictionary = {}
var bot_clocks: Dictionary = {}
var move_pads: Dictionary = {}
var pending_moves: Dictionary = {}
var feedback_text: String = ""

func _ready() -> void:
	game_id = "dance"
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		scores[p.id] = 0
		progress[p.id] = 0
		failed[p.id] = false
		poses[p.id] = -1
		pose_times[p.id] = -10.0
		bot_clocks[p.id] = 0.0
		var dancer = Avatar.new()
		dancer.skin = p.skin
		dancer.tint = p.color
		add_child(dancer)
		runners[p.id] = dancer
	if roster.size() > 1:
		leader_id = roster[rng.randi_range(0, roster.size() - 1)].id
	else:
		# Solo players copy a virtual dance teacher.
		for i in range(SEQUENCE_LENGTH):
			sequence.append(rng.randi_range(0, 3))
		begin_watch()

func can_move(id: int) -> bool:
	if ended or paused or countdown > 0:
		return false
	if phase == "create":
		return id == leader_id and sequence.size() < SEQUENCE_LENGTH
	return phase == "repeat" and id != leader_id and not failed[id] and progress[id] < SEQUENCE_LENGTH

func pose(id: int, move: int) -> void:
	if poses.has(id):
		poses[id] = move
		pose_times[id] = time
	audio.tone([520, 660, 780, 900][move])
	queue_redraw()

func choose_move(id: int, move: int) -> void:
	if move < 0 or move >= MOVES.size() or not can_move(id):
		return
	pose(id, move)
	if phase == "create":
		sequence.append(move)
		if sequence.size() == SEQUENCE_LENGTH:
			begin_watch()
	else:
		if move != sequence[progress[id]]:
			failed[id] = true
			feedback_text = "P%d missed a move!" % (id + 1)
		else:
			progress[id] += 1
			scores[id] = progress[id]
			if progress[id] == SEQUENCE_LENGTH:
				feedback_text = "P%d · PERFECT DANCE!" % (id + 1)

func begin_watch() -> void:
	phase = "watch"
	phase_time = 0
	watch_index = -1
	feedback_text = "Watch all five moves. Remember the order!"

func begin_repeat() -> void:
	phase = "repeat"
	phase_time = 0
	feedback_text = "Copy every move in order!"
	for id in bot_clocks:
		bot_clocks[id] = 0

func successful_ids() -> Array:
	var ids: Array = []
	for p in roster:
		if p.id != leader_id and not failed[p.id] and progress[p.id] == SEQUENCE_LENGTH:
			ids.append(p.id)
	return ids

func has_winner() -> bool:
	return leader_id >= 0 or not successful_ids().is_empty()

func finish_copy() -> void:
	if phase == "finish" or ended:
		return
	for p in roster:
		if p.id != leader_id and progress[p.id] < SEQUENCE_LENGTH:
			failed[p.id] = true
	var successes: Array = successful_ids()
	if leader_id >= 0:
		# The leader wins only if nobody can copy the complete dance.
		scores[leader_id] = SEQUENCE_LENGTH if successes.is_empty() else 0
	phase = "finish"
	phase_time = 0
	feedback_text = "Perfect dance!" if not successes.is_empty() else "The leader wins!" if leader_id >= 0 else "Try the full sequence again!"

func _process(delta: float) -> void:
	if paused or ended:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - delta)
		queue_redraw()
		return
	time += delta
	phase_time += delta
	match phase:
		"create":
			for p in roster:
				if p.id == leader_id and p.bot:
					bot_clocks[p.id] += delta
					if bot_clocks[p.id] >= 0.65:
						bot_clocks[p.id] = 0
						choose_move(p.id, rng.randi_range(0, 3))
			if phase == "create" and phase_time >= 12:
				while sequence.size() < SEQUENCE_LENGTH:
					sequence.append(rng.randi_range(0, 3))
				begin_watch()
		"watch":
			var index: int = floori(phase_time / BEAT)
			if index < sequence.size() and index != watch_index:
				watch_index = index
				pose(leader_id if leader_id >= 0 else roster[0].id, sequence[index])
			if phase_time >= SEQUENCE_LENGTH * BEAT + 0.45:
				begin_repeat()
		"repeat":
			var resolved: bool = true
			for p in roster:
				if p.id == leader_id:
					continue
				if not failed[p.id] and progress[p.id] < SEQUENCE_LENGTH:
					resolved = false
					if p.bot:
						bot_clocks[p.id] += delta
						if bot_clocks[p.id] >= [0.85, 0.65, 0.45][Party.difficulty]:
							bot_clocks[p.id] = 0
							var next: int = sequence[progress[p.id]]
							if rng.randf() > [0.70, 0.86, 0.98][Party.difficulty]:
								next = (next + rng.randi_range(1, 3)) % MOVES.size()
							choose_move(p.id, next)
			if resolved or phase_time >= 12:
				finish_copy()
		"finish":
			if phase_time >= 1.0:
				complete()
	queue_redraw()

func activate(id: int) -> void:
	choose_move(id, int(pending_moves.get(id, -1)))

func corner_at(pos: Vector2) -> int:
	for p in roster:
		if p.bot or not can_move(p.id) or not move_pads.has(p.id):
			continue
		for move in range(MOVES.size()):
			if move_pads[p.id][move].has_point(pos):
				pending_moves[p.id] = move
				return p.id
	return -1

func press_at(pos: Vector2) -> void:
	var id: int = corner_at(pos)
	if id >= 0:
		press_corner(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var keys: Array = [[KEY_Q, KEY_W, KEY_E, KEY_R], [KEY_U, KEY_I, KEY_O, KEY_P], [KEY_A, KEY_S, KEY_D, KEY_F], [KEY_H, KEY_J, KEY_K, KEY_L]]
	for p in roster:
		if not p.bot:
			var move: int = keys[p.id].find(event.physical_keycode)
			if move >= 0:
				choose_move(p.id, move)

func player_status(id: int) -> String:
	if id == leader_id:
		return "LEADER" if phase == "create" else "WATCH" if phase == "watch" else "WAIT"
	if failed[id]:
		return "MISSED"
	if progress[id] == SEQUENCE_LENGTH:
		return "PERFECT!"
	return "COPY NOW" if phase == "repeat" else "WATCH"

func corner_controls(_interactive: bool = true) -> void:
	pads.clear()
	move_pads.clear()
	for p in roster:
		var pos = Vector2(8 if p.id % 2 == 0 else size.x - 184, size.y - 164 if p.id < 2 else 8)
		if size.y > size.x and roster.size() <= 2:
			pos.y = size.y - 164
			pos.x = (size.x - 176) / 2 if roster.size() == 1 else (8.0 if roster.find(p) == 0 else size.x - 184)
		var rect = Rect2(pos, Vector2(176, 156))
		pads[p.id] = rect
		var enabled: bool = can_move(p.id)
		var color: Color = p.color if enabled else p.color.darkened(0.45)
		draw_style_box(style(Color("18233b"), 18), rect)
		text_at("P%d · %s" % [p.id + 1, "BOT" if p.bot else player_status(p.id)], pos + Vector2(88 if p.bot else 76, 24), 14, p.color)
		if p.bot:
			draw_robot_control(pos + Vector2(88, 76))
			text_at("BOT · " + player_status(p.id), pos + Vector2(88, 132), 17, Color("a4afc8"))
			continue
		draw_finger(pos + Vector2(159, 22), 0.3, Color.WHITE if enabled else Color("657087"))
		move_pads[p.id] = []
		for move in range(MOVES.size()):
			var button_rect = Rect2(pos + Vector2(7 + (move % 2) * 82, 36 + floori(move / 2.0) * 56), Vector2(78, 50))
			move_pads[p.id].append(button_rect)
			var amount: float = float(finger_amounts.get(p.id, 0)) if pending_moves.get(p.id, -1) == move else 0.0
			var drawn = button_rect.grow(-amount * 2)
			drawn.position.y += amount * 2
			draw_style_box(style(MOVE_COLORS[move].darkened(0.60 if enabled else 0.85), 10), drawn)
			text_at(SYMBOLS[move], drawn.get_center() - Vector2(0, 2), 22, Color.WHITE if enabled else color)
			text_at(MOVES[move], drawn.get_center() + Vector2(0, 17), 11, Color.WHITE if enabled else color)

func _draw() -> void:
	var remaining: int = ceili(maxf(0, 12 - phase_time))
	round_clock("MAKE · %ds" % remaining if phase == "create" else "WATCH!" if phase == "watch" else "COPY · %ds" % remaining if phase == "repeat" else "DANCE!")
	var title: String = "P%d IS THE DANCE LEADER!" % (leader_id + 1) if leader_id >= 0 else "COPY THE DANCE TEACHER!"
	text_at(title, Vector2(size.x / 2, 188), 24, Color("ffd577"))
	text_at("Choose five moves" if phase == "create" else feedback_text, Vector2(size.x / 2, 216), 18, Color.WHITE)
	var chip_width: float = minf(104, (size.x - 32) / SEQUENCE_LENGTH)
	for i in range(SEQUENCE_LENGTH):
		var rect = Rect2(Vector2(size.x / 2 - chip_width * SEQUENCE_LENGTH / 2 + i * chip_width + 3, 236), Vector2(chip_width - 6, 48))
		var shown: bool = i < sequence.size() and phase != "repeat"
		var color: Color = MOVE_COLORS[sequence[i]] if shown else Color("42516b")
		draw_style_box(style(color.darkened(0.7), 12), rect)
		if phase == "watch" and i == watch_index:
			var border = style(Color.TRANSPARENT, 12)
			border.set_border_width_all(3)
			border.border_color = color
			draw_style_box(border, rect.grow(2))
		text_at("%d · %s" % [i + 1, SYMBOLS[sequence[i]] if shown else "?"], rect.get_center() + Vector2(0, 6), 21, color if shown else Color("a4afc8"))
	var columns: int = roster.size() if size.x > size.y else mini(2, roster.size())
	var rows: int = ceili(float(roster.size()) / columns)
	var area = Rect2(16, 302, size.x - 32, maxf(100, size.y - 482))
	var cell: Vector2 = Vector2((area.size.x - (columns - 1) * 12) / columns, (area.size.y - (rows - 1) * 12) / rows)
	for i in range(roster.size()):
		var p: Dictionary = roster[i]
		var rect = Rect2(area.position + Vector2(i % columns, floori(float(i) / columns)) * (cell + Vector2(12, 12)), cell)
		draw_style_box(style(Color("20233e"), 18), rect)
		var active: bool = p.id == leader_id if phase in ["create", "watch"] else can_move(p.id)
		if active:
			var outline = style(Color.TRANSPARENT, 18)
			outline.set_border_width_all(2)
			outline.border_color = p.color
			draw_style_box(outline, rect)
		text_at("P%d%s · %s" % [p.id + 1, " BOT" if p.bot else "", player_status(p.id)], Vector2(rect.get_center().x, rect.position.y + 26), 16, p.color)
		var elapsed: float = time - float(pose_times[p.id])
		var pulse: float = sin(clampf(elapsed / BEAT, 0, 1) * PI)
		var move: int = poses[p.id]
		var height: float = clampf(cell.y * 0.37, 46, 94)
		var hop: float = pulse * 25 if move == 1 else 0.0
		var angle: float = pulse * TAU if move == 2 else sin(elapsed * 10) * pulse * 0.12 if move == 0 else 0.0
		var foot: Vector2 = rect.get_center() + Vector2(0, height * 0.5 - hop)
		var color: Color = p.color.darkened(0.5) if failed[p.id] else p.color
		draw_set_transform(foot, angle, Vector2.ONE)
		draw_style_box(style(color, 8), Rect2(-14, -height * 0.55, 28, height * 0.32))
		for side in [-1, 1]:
			draw_line(Vector2(side * 7, -height * 0.25), Vector2(side * 15, 0), color, 6, true)
			var hand = Vector2(side * (7 if move == 3 else 32), -height * (0.55 + pulse * 0.4 if move == 0 else 0.42))
			if move == 3:
				hand.x = side * lerpf(30, 3, pulse)
			draw_line(Vector2(side * 13, -height * 0.5), hand, color, 5, true)
			circle(hand, 5, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		var dancer: Control = runners[p.id]
		dancer.size = Vector2.ONE * height * 0.65
		dancer.pivot_offset = dancer.size / 2
		dancer.rotation = angle
		dancer.position = foot + Vector2(0, -height * 0.675).rotated(angle) - dancer.size / 2
		dancer.modulate.a = 0.45 if failed[p.id] else 1.0
		if elapsed < BEAT and move >= 0:
			text_at(MOVES[move], Vector2(rect.get_center().x, rect.end.y - 32), 18, MOVE_COLORS[move])
		for step in range(SEQUENCE_LENGTH):
			circle(Vector2(rect.get_center().x + (step - 2) * 15, rect.end.y - 15), 4, p.color if step < progress[p.id] else Color("42516b"))
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at(title, size / 2 + Vector2(0, 60), 22, Color("ffd577"))
