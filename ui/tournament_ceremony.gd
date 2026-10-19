extends Control
const Avatar = preload("res://ui/avatar.gd")
var roster: Array = []
var winners: Array = []
var totals: Dictionary = {}
var age: float = 0.0
var dancers: Dictionary = {}
var confetti: Array = []
var podium_order: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = 240
	var ranked: Array = roster.duplicate(true)
	ranked.sort_custom(func(a, b): return int(totals.get(a.id, 0)) > int(totals.get(b.id, 0)))
	# Place single champions near the middle; tied champions each retain their own trophy.
	podium_order = ranked
	if winners.size() == 1 and ranked.size() >= 3:
		var champion: Dictionary = podium_order.pop_front()
		podium_order.insert(1, champion)
	for player in roster:
		var avatar = Avatar.new()
		avatar.skin = player.skin
		avatar.tint = player.color
		avatar.animate = false
		add_child(avatar)
		dancers[player.id] = avatar
	var rng = RandomNumberGenerator.new()
	rng.seed = 416
	for i in range(90):
		confetti.append({"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(0.12, 0.30), "spin": rng.randf_range(-4, 4), "color": [Color("ffd577"), Color("ff718f"), Color("73c9ff"), Color("6ce5bc"), Color("b3a0ff")][i % 5], "length": rng.randf_range(4, 9)})

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func panel(color: Color, radius: int = 16) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

func word(value: String, center: Vector2, font_size: int, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func trophy(center: Vector2, scale_value: float) -> void:
	draw_set_transform(center, 0, Vector2.ONE * scale_value)
	# Gold handles, bowl, stem, and foot.
	for side in [-1, 1]:
		draw_arc(Vector2(side * 0.95, -0.8), 0.59, -PI * 0.95, PI * 0.95, 24, Color("d58c2f"), 0.22, true)
	var bowl = PackedVector2Array([Vector2(-1.0, -1.3), Vector2(1.0, -1.3), Vector2(0.72, -0.42), Vector2(0.35, -0.08), Vector2(-0.35, -0.08), Vector2(-0.72, -0.42)])
	draw_colored_polygon(bowl, Color("ffc94d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-0.9, -1.2), Vector2(-0.45, -1.2), Vector2(-0.30, -0.23), Vector2(-0.58, -0.45)]), Color("ffe99c"))
	draw_line(Vector2(-1, -1.3), Vector2(1, -1.3), Color("ffe99c"), 0.14, true)
	draw_rect(Rect2(-0.14, -0.1, 0.28, 0.74), Color("e5a33b"))
	draw_style_box(panel(Color("ffc94d"), 0), Rect2(-0.70, 0.57, 1.40, 0.24))
	draw_style_box(panel(Color("b97828"), 0), Rect2(-0.82, 0.80, 1.64, 0.15))
	# The red diamond sits at the very top of every winner's cup.
	var gem_center = Vector2(0, -1.78)
	var gem = PackedVector2Array([gem_center + Vector2(0, -0.52), gem_center + Vector2(0.42, 0), gem_center + Vector2(0, 0.52), gem_center + Vector2(-0.42, 0)])
	draw_colored_polygon(gem, Color("ef3553"))
	draw_colored_polygon(PackedVector2Array([gem[0], gem[1], gem_center]), Color("ff9ba8"))
	draw_colored_polygon(PackedVector2Array([gem[1], gem[2], gem_center]), Color("ae153a"))
	draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]), Color("ffd577"), 0.07, true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_style_box(panel(Color("17213c"), 22), Rect2(Vector2.ZERO, size))
	var floor_y: float = size.y - 42
	var count: int = maxi(1, podium_order.size())
	var cell_width: float = size.x / count
	var body_height: float = clampf(minf((size.y - 60) * 0.30, cell_width * 0.48), 40, 100)
	var reveal: float = 1 - pow(1 - clampf(age / 0.95, 0, 1), 3)
	draw_style_box(panel(Color("263452"), 12), Rect2(12, floor_y - 2, size.x - 24, 8))
	for player in podium_order:
		var index: int = podium_order.find(player)
		var champion: bool = winners.has(player.id)
		var x: float = (index + 0.5) * cell_width
		var pedestal_height: float = 30 if champion else 7
		var pedestal = Rect2(x - cell_width * 0.38, floor_y - pedestal_height, cell_width * 0.76, pedestal_height)
		draw_style_box(panel(Color("99723c") if champion else Color("34425e"), 8), pedestal)
		if champion:
			word("1", Vector2(x, floor_y - 8), 20, Color("ffe39a"))
		var bounce: float = sin(age * 4) * 2 if champion and age > 0.95 else 0
		var foot = Vector2(x, floor_y - pedestal_height - bounce)
		var color: Color = player.color
		draw_style_box(panel(color, 7), Rect2(foot + Vector2(-body_height * 0.15, -body_height * 0.59), Vector2(body_height * 0.30, body_height * 0.34)))
		for side in [-1, 1]:
			draw_line(foot + Vector2(side * body_height * 0.08, -body_height * 0.27), foot + Vector2(side * body_height * 0.19, 0), color, 6, true)
		var cup_scale: float = body_height * 0.21
		var cup_center: Vector2 = foot - Vector2(0, body_height * lerpf(0.30, 1.24, reveal))
		for side in [-1, 1]:
			var shoulder: Vector2 = foot + Vector2(side * body_height * 0.14, -body_height * 0.54)
			var hand: Vector2 = cup_center + Vector2(side * cup_scale * 1.25, -cup_scale * 0.62) if champion else foot + Vector2(side * body_height * 0.30, -body_height * 0.25)
			draw_line(shoulder, hand, color, 5, true)
			draw_circle(hand, 4, Color.WHITE, true, -1, true)
		var avatar: Control = dancers[player.id]
		avatar.size = Vector2.ONE * body_height * 0.80
		avatar.position = foot - Vector2(avatar.size.x / 2, body_height * 1.1)
		if champion:
			trophy(cup_center, cup_scale)
		word("P%d%s" % [player.id + 1, " BOT" if player.bot else ""], Vector2(x, floor_y + 25), 19, color)
	# Confetti continues gently falling after the cup-raising animation.
	for piece in confetti:
		var point = Vector2(piece.x * size.x + sin(age + piece.y * 8) * 12, fposmod(piece.y + age * piece.speed, 1.2) * size.y - size.y * 0.1)
		var offset: Vector2 = Vector2.from_angle(age * piece.spin) * piece.length / 2
		draw_line(point - offset, point + offset, piece.color, 3, true)
