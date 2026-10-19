extends "res://games/arena.gd"
var deck: Array = []
var opened: Array = []
var matched: Dictionary = {}
var observed: Dictionary = {}
var flips: Array = []
var card_rects: Array = []
var turn: int = 0
var reveal_time: float = 0.0
var bot_time: float = 0.0
var pairs_found: int = 0
var cursor: int = 0
var board_cols: int = 4
const SYMBOLS = ["SUN", "MOON", "STAR", "GEM", "CAT", "LEAF", "HEART", "BOLT"]
const INKS = [Color("ffd577"), Color("b3a0ff"), Color("73c9ff"), Color("6ce5bc"), Color("ffb276"), Color("a9de7c"), Color("ff8cad"), Color("e0c0ff")]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		scores[p.id] = 0
	for i in range(8):
		deck.append(i)
		deck.append(i)
	deck.shuffle()
	for i in range(16):
		flips.append(0.0)

func _process(delta: float) -> void:
	if paused or ended:
		return
	if countdown > 0:
		countdown -= delta
		queue_redraw()
		return
	time += delta
	for i in range(16):
		var target: float = 1.0 if opened.has(i) or matched.has(i) else 0.0
		flips[i] = move_toward(flips[i], target, delta * 4.0)
	if opened.size() == 2:
		reveal_time += delta
		if reveal_time >= 1.05:
			resolve_pair()
	elif roster[turn].bot:
		bot_time += delta
		if bot_time >= [1.1, 0.8, 0.55][Party.difficulty]:
			bot_time = 0
			choose_card(bot_choice(), true)
	queue_redraw()

func choose_card(index: int, by_bot: bool = false) -> void:
	if ended or paused or countdown > 0 or index < 0 or index >= 16 or opened.size() >= 2 or matched.has(index) or opened.has(index):
		return
	if roster[turn].bot != by_bot:
		return
	opened.append(index)
	# Bots only remember cards actually revealed on the shared board.
	observed[index] = deck[index]
	reveal_time = 0
	audio.tone(500 + deck[index] * 60)
	queue_redraw()

func resolve_pair() -> void:
	if opened.size() != 2:
		return
	if deck[opened[0]] == deck[opened[1]]:
		for index in opened:
			matched[index] = roster[turn].id
		scores[roster[turn].id] += 1
		pairs_found += 1
		audio.tone(1000)
	opened.clear()
	reveal_time = 0
	bot_time = -0.35
	turn = (turn + 1) % roster.size()
	if pairs_found == 8:
		complete()

func bot_choice() -> int:
	var available: Array = []
	for i in range(16):
		if not matched.has(i) and not opened.has(i):
			available.append(i)
	var remember: bool = rng.randf() < [0.35, 0.75, 1.0][Party.difficulty]
	if remember:
		for i in available:
			if not observed.has(i):
				continue
			if opened.size() == 1 and observed[i] == deck[opened[0]]:
				return i
			if opened.is_empty():
				for j in available:
					if i != j and observed.has(j) and observed[i] == observed[j]:
						return i
	return available[rng.randi_range(0, available.size() - 1)] if not available.is_empty() else -1

func press_at(pos: Vector2) -> void:
	for i in range(card_rects.size()):
		if card_rects[i].has_point(pos):
			choose_card(i)
			return

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: cursor = (cursor + 15) % 16
			KEY_RIGHT: cursor = (cursor + 1) % 16
			KEY_UP: cursor = (cursor + 16 - board_cols) % 16
			KEY_DOWN: cursor = (cursor + board_cols) % 16
			KEY_SPACE, KEY_ENTER: choose_card(cursor)
		queue_redraw()

func control_is_highlighted(id: int) -> bool:
	return not roster.is_empty() and roster[turn].id == id

func control_label(id: int, bot: bool) -> String:
	if bot:
		return "P%d · BOT" % (id + 1)
	return "P%d · %s" % [id + 1, ("BOT" if bot else "TURN") if control_is_highlighted(id) else "WAIT"]

func turn_instruction() -> String:
	if roster[turn].bot:
		return "Bot is choosing · please wait"
	if opened.size() == 2:
		return "Checking this pair…"
	return "Tap a card" if opened.size() == 1 else "Tap two cards"

func _draw() -> void:
	if roster.is_empty():
		return
	var active = roster[turn]
	round_clock("P%d%s · turn" % [active.id + 1, " BOT" if active.bot else ""])
	var has_top_controls: bool = false
	for player in roster:
		if player.id >= 2:
			has_top_controls = true
	var top: float = 156 if has_top_controls else 116
	var bottom: float = 148
	var area = Rect2(12, top, size.x - 24, size.y - top - bottom)
	board_cols = 8 if size.x > size.y else 4
	var board_rows: int = 16 / board_cols
	var gap: Vector2 = Vector2((board_cols - 1) * 12, (board_rows - 1) * 12)
	var tile: Vector2 = Vector2(minf(140, (area.size.x - gap.x) / board_cols), minf(160, (area.size.y - gap.y) / board_rows))
	var board_size: Vector2 = tile * Vector2(board_cols, board_rows) + gap
	var start: Vector2 = area.position + (area.size - board_size) / 2
	card_rects.clear()
	for i in range(16):
		var rect = Rect2(start + Vector2(i % board_cols, floori(float(i) / board_cols)) * (tile + Vector2(12, 12)), tile)
		card_rects.append(rect)
		var face: bool = flips[i] >= 0.5
		var width_factor: float = maxf(0.04, absf(cos(flips[i] * PI)))
		var animated = Rect2(rect.get_center() - Vector2(tile.x * width_factor, tile.y) / 2, Vector2(tile.x * width_factor, tile.y))
		var color: Color = Color("23314d") if not face else INKS[deck[i]].darkened(0.72)
		if matched.has(i):
			color = Party.COLORS[matched[i]].darkened(0.65)
		draw_style_box(style(Color(0, 0, 0, 0.23), 16), Rect2(animated.position + Vector2(0, 5), animated.size))
		draw_style_box(style(color, 16), animated)
		if not matched.has(i) and not active.bot and opened.size() < 2:
			draw_style_box(card_outline(active.color), animated)
		if width_factor > 0.55:
			var c = rect.get_center() - Vector2(0, 5)
			if face:
				draw_symbol(deck[i], c, minf(tile.x, tile.y) * 0.22)
				text_at(SYMBOLS[deck[i]], rect.get_center() + Vector2(0, tile.y * 0.34), clampi(int(tile.x * 0.14), 12, 20), INKS[deck[i]])
			else:
				text_at("?", c + Vector2(0, 14), int(minf(tile.x, tile.y) * 0.43), PURPLE_COLOR())
				text_at("%02d" % (i + 1), rect.get_center() + Vector2(0, tile.y * 0.34), 12, Color("73829f"))
		if i == cursor and not OS.has_feature("mobile"):
			draw_rect(rect.grow(3), active.color, false, 2)
	corner_controls(false)
	var banner_inset: float = 132 if has_top_controls else 16
	var banner = Rect2(banner_inset, 53, size.x - banner_inset * 2, 54)
	draw_style_box(style(active.color.darkened(0.68), 14), banner)
	draw_style_box(card_outline(active.color), banner)
	text_at("PLAYER %d · %s" % [active.id + 1, "BOT'S TURN" if active.bot else "YOUR TURN"], Vector2(size.x * 0.5, 75), 22, active.color)
	text_at(turn_instruction(), Vector2(size.x * 0.5, 97), 17, Color.WHITE)
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at("Remember the faces. Find the pairs.", size / 2 + Vector2(0, 65), 22)

func card_outline(color: Color) -> StyleBoxFlat:
	var outline = style(Color.TRANSPARENT, 14)
	outline.set_border_width_all(2)
	outline.border_color = color
	return outline

func PURPLE_COLOR() -> Color:
	return Color("b3a0ff")

func draw_symbol(symbol: int, center: Vector2, radius: float) -> void:
	var ink: Color = INKS[symbol]
	match symbol:
		0:
			circle(center, radius * 0.65, ink)
			for i in range(8):
				var v = Vector2.from_angle(i * TAU / 8)
				draw_line(center + v * radius * 0.85, center + v * radius * 1.15, ink, 3, true)
		1:
			circle(center, radius, ink)
			circle(center + Vector2(radius * 0.45, -radius * 0.28), radius * 0.82, Color("202239"))
		2, 3:
			var points = PackedVector2Array()
			for i in range(10 if symbol == 2 else 4):
				points.append(center + Vector2.from_angle(-PI / 2 + i * TAU / (10 if symbol == 2 else 4)) * radius * (0.5 if symbol == 2 and i % 2 else 1.0))
			draw_colored_polygon(points, ink)
		4:
			circle(center, radius, ink)
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([center + Vector2(side * radius, 0), center + Vector2(side * radius, -radius * 1.3), center + Vector2(0, -radius * 0.6)]), ink)
				circle(center + Vector2(side * radius * 0.35, 0), 3, Color("11182b"))
		5:
			draw_set_transform(center, -0.5, Vector2(1.0, 0.65))
			circle(Vector2.ZERO, radius, ink)
			draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color("11182b"), 3)
			draw_set_transform(Vector2.ZERO)
		6:
			circle(center + Vector2(-radius * 0.4, -radius * 0.25), radius * 0.6, ink)
			circle(center + Vector2(radius * 0.4, -radius * 0.25), radius * 0.6, ink)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, -radius * 0.1), center + Vector2(radius, -radius * 0.1), center + Vector2(0, radius)]), ink)
		7:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(-radius * 0.7, radius * 0.2), center + Vector2(0, radius * 0.1), center + Vector2(0, radius), center + Vector2(radius * 0.7, -radius * 0.2), center + Vector2(0, -radius * 0.1)]), ink)
