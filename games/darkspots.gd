extends "res://games/arena.gd"
const Palette = preload("res://ui/game_palette.gd")
const LAP_SPEED: float = 0.48
const MIN_RANGE_LENGTH: float = 0.06
const MAX_RANGE_LENGTH: float = 0.12
var positions: Dictionary = {}
var targets: Dictionary = {}
var target_indices: Dictionary = {}
var target_sequence: Array = []
var length_sequence: Array = []
var range_lengths: Dictionary = {}
var tap_times: Dictionary = {}
var pulses: Dictionary = {}
var messages: Dictionary = {}
var bot_attempted: Dictionary = {}
var message_times: Dictionary = {}
var displayed_states: Dictionary = {}
const DISPLAY_GRACE_SECONDS: float = 0.1
const TAP_DEBOUNCE_SECONDS: float = 0.04

func _ready() -> void:
	duration = 20.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	# Every seat follows the same target sequence and orbit speed.
	var target: float = rng.randf_range(0.15, 0.85)
	var previous_length: float = 0.0
	for i in range(100):
		var next_length: float = rng.randf_range(MIN_RANGE_LENGTH, MAX_RANGE_LENGTH)
		while absf(next_length - previous_length) < 0.0125:
			next_length = rng.randf_range(MIN_RANGE_LENGTH, MAX_RANGE_LENGTH)
		length_sequence.append(next_length)
		previous_length = next_length
		target_sequence.append(target)
		target = fposmod(target + rng.randf_range(0.22, 0.78), 1.0)
	for p in roster:
		scores[p.id] = 0
		positions[p.id] = 0.0
		targets[p.id] = target_sequence[0]
		range_lengths[p.id] = length_sequence[0]
		target_indices[p.id] = 0
		tap_times[p.id] = -1.0
		pulses[p.id] = 0.0
		messages[p.id] = "TAP INSIDE THE GOLD RANGE"
		bot_attempted[p.id] = false
		message_times[p.id] = -10.0

static func perimeter_point(square: Rect2, progress: float) -> Vector2:
	var t: float = fposmod(progress, 1.0) * 4.0
	var corners = [square.position, square.position + Vector2(square.size.x, 0), square.end, square.position + Vector2(0, square.size.y)]
	var edge: int = int(t)
	return corners[edge].lerp(corners[(edge + 1) % 4], t - edge)

static func perimeter_range(square: Rect2, center: float, length: float) -> PackedVector2Array:
	# Split exactly at corners, including ranges crossing the perimeter origin.
	var start: float = center - length / 2
	var finish: float = center + length / 2
	var result = PackedVector2Array([perimeter_point(square, start)])
	var corner: float = (floorf(start * 4) + 1) / 4
	while corner < finish:
		result.append(perimeter_point(square, corner))
		corner += 0.25
	result.append(perimeter_point(square, finish))
	return result

static func orbit_distance(a: float, b: float) -> float:
	var difference: float = absf(a - b)
	return minf(difference, 1.0 - difference)

func _process(delta: float) -> void:
	if NetPlay.client_frame(self, delta):
		return
	if paused or ended:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - delta)
		queue_redraw()
		return
	time = minf(duration, time + delta)
	for p in roster:
		positions[p.id] = fposmod(time * LAP_SPEED, 1.0)
		pulses[p.id] = maxf(0, pulses[p.id] - delta * 3.5)
		var distance: float = orbit_distance(positions[p.id], targets[p.id])
		if distance > range_lengths[p.id] / 2 + 0.03:
			bot_attempted[p.id] = false
		if p.bot and distance <= 0.025 and not bot_attempted[p.id]:
			bot_attempted[p.id] = true
			if rng.randf() < [0.50, 0.75, 0.95][Party.difficulty]:
				activate(p.id)
	if time >= duration:
		complete()
	queue_redraw()

func board_square(id: int) -> Rect2:
	var cols: int = mini(2, roster.size()) if size.y > size.x else roster.size()
	var rows: int = ceili(float(roster.size()) / cols)
	var cell = Vector2((size.x - (cols - 1) * 12) / cols, (size.y - 220 - (rows - 1) * 12) / rows)
	var side: float = maxf(30, minf(cell.x - 65, cell.y - 85))
	var index: int = 0
	for i in range(roster.size()):
		if roster[i].id == id:
			index = i
	var center = Vector2((index % cols) * (cell.x + 12), 110 + floorf(float(index) / cols) * (cell.y + 12)) + cell / 2 - Vector2(0, 6)
	return Rect2(center - Vector2.ONE * side / 2, Vector2.ONE * side)

static func visible_overlap(square: Rect2, position: float, target: float, length: float) -> bool:
	var marker = perimeter_point(square, position)
	var stripe = perimeter_range(square, target, length)
	# Match the ring's outer stroke and the gold stripe's visible thickness.
	var reach: float = clampf(square.size.x * 0.085, 10, 23) + 6 + clampf(square.size.x * 0.15, 16, 32) / 2
	for i in range(stripe.size() - 1):
		if marker.distance_to(Geometry2D.get_closest_point_to_segment(marker, stripe[i], stripe[i + 1])) <= reach:
			return true
	return false

func ring_overlap_allowance() -> float:
	var side: float = board_square(roster[0].id).size.x
	return (clampf(side * 0.085, 10, 23) + 6 + clampf(side * 0.15, 16, 32) / 2) / (side * 4)

func tap_overlaps(id: int, bot: bool) -> bool:
	if NetPlay.remote_taps.has(id):
		var seen: Dictionary = NetPlay.remote_taps[id]
		# Judge the recent frame the player actually saw, bounded to 250ms.
		if seen.get("index", -1) == target_indices[id] and seen.get("time") is float and seen.get("position") is float and seen.get("square") is Rect2:
			var age: float = time - seen.time
			var square: Rect2 = seen.square
			if age >= 0 and age <= 0.25 and square.size.x >= 30 and square.size.x <= 2000 and absf(square.size.x - square.size.y) < 1 and orbit_distance(seen.position, fposmod(seen.time * LAP_SPEED, 1.0)) < 0.01:
				return visible_overlap(square, seen.position, targets[id], range_lengths[id])
		return false
	if visible_overlap(board_square(id), positions[id], targets[id], range_lengths[id]):
		return true
	if bot or not displayed_states.has(id):
		return false
	var shown: Dictionary = displayed_states[id]
	# Only accept a recent frame of this same target, never the previous scored target.
	if shown.index != target_indices[id] or time - shown.time < 0 or time - shown.time > DISPLAY_GRACE_SECONDS or Time.get_ticks_msec() - shown.ticks > 100:
		return false
	return visible_overlap(shown.square, shown.position, shown.target, shown.length)

func activate(id: int) -> void:
	if NetPlay.intercept(id, "tap"):
		return
	if ended or paused or countdown > 0 or time >= duration or not scores.has(id):
		return
	if time - tap_times[id] < TAP_DEBOUNCE_SECONDS:
		return
	tap_times[id] = time
	pulses[id] = 1.0
	message_times[id] = time
	var bot: bool = false
	for player in roster:
		if player.id == id:
			bot = player.bot
	if tap_overlaps(id, bot):
		scores[id] += 5
		target_indices[id] += 1
		targets[id] = target_sequence[target_indices[id] % target_sequence.size()]
		range_lengths[id] = length_sequence[target_indices[id] % length_sequence.size()]
		messages[id] = "+5  ·  NICE HIT!"
		audio.tone(740 + id * 70)
	else:
		messages[id] = "MISS · wait for gold"
		audio.tone(230)
	queue_redraw()

func _draw() -> void:
	var remaining: int = maxi(0, ceili(duration - time))
	round_clock("%02d:%02d" % [remaining / 60, remaining % 60])
	var portrait: bool = size.y > size.x
	var cols: int = mini(2, roster.size()) if portrait else roster.size()
	var rows: int = ceili(float(roster.size()) / cols)
	var cell = Vector2((size.x - (cols - 1) * 12) / cols, (size.y - 220 - (rows - 1) * 12) / rows)
	pads.clear()
	for i in range(roster.size()):
		var p = roster[i]
		var rect = Rect2(Vector2((i % cols) * (cell.x + 12), 110 + floorf(float(i) / cols) * (cell.y + 12)), cell)
		pads[p.id] = rect
		draw_style_box(style(Color("17243c"), 22), rect)
		var side: float = maxf(30, minf(cell.x - 65, cell.y - 85))
		var center: Vector2 = rect.get_center() - Vector2(0, 6)
		var square = board_square(p.id)
		displayed_states[p.id] = {"square": square, "position": positions[p.id], "target": targets[p.id], "length": range_lengths[p.id], "index": target_indices[p.id], "time": time, "ticks": Time.get_ticks_msec()}
		draw_texture_rect(Palette.rainbow_square(), square, false)
		draw_rect(square, Color("334562"), false, 2)
		var target: Vector2 = perimeter_point(square, targets[p.id])
		var marker: Vector2 = perimeter_point(square, positions[p.id])
		var radius: float = clampf(side * 0.085, 10, 23)
		var range_points = perimeter_range(square, targets[p.id], range_lengths[p.id])
		var thickness: float = clampf(side * 0.15, 16, 32)
		draw_polyline(range_points, Color("805614"), thickness + 4, true)
		for corner in range(1, range_points.size() - 1):
			circle(range_points[corner], thickness / 2 + 2, Color("805614"))
		draw_polyline(range_points, Color("ffd15c"), thickness, true)
		for corner in range(1, range_points.size() - 1):
			circle(range_points[corner], thickness / 2, Color("ffd15c"))
		# The moving ring leaves the full gold range visible when they overlap.
		draw_arc(marker, radius + 3, 0, TAU, 40, Color("17243c"), 10, true)
		draw_arc(marker, radius + 3, 0, TAU, 40, p.color, 6, true)
		circle(marker, radius * 0.44, p.color)
		text_at(str(scores[p.id]), center + Vector2(0, 18), 54, Color("334562"))
		var fresh_feedback: bool = time - message_times[p.id] < 0.9
		var hint: String = messages[p.id] if fresh_feedback else "Tap your finger on gold"
		var hint_color: Color = Color("6ce5bc") if fresh_feedback and messages[p.id].begins_with("+5") else Color("ffb276") if fresh_feedback else Color("c9d6ea")
		text_at(hint, Vector2(center.x, square.end.y + 38), 16 if cell.x < 300 else 20, hint_color)
		if pulses[p.id] > 0:
			var color: Color = p.color if messages[p.id].begins_with("+5") else Color("ffb276")
			color.a = pulses[p.id] * 0.7
			draw_arc(target, radius * (1.4 + (1.0 - pulses[p.id]) * 1.7), 0, TAU, 48, color, 3, true)
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at("Tap anywhere inside the gold range.", size / 2 + Vector2(0, 65), 22)
