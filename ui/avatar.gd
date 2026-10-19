extends Control
var tint: Color = Color("b3a0ff")
var skin: String = "classic"
var animate: bool = false
var phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if animate:
		phase += delta
		queue_redraw()

func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.32
	var c: Vector2 = size * 0.5 + Vector2(0, sin(phase * 2.5) * 4 if animate else 0)
	circle(c + Vector2(0, r * 0.95), r * 0.8, Color(0, 0, 0, 0.18))
	if skin in ["rabbit", "koala", "panda", "capybara"]:
		draw_animal(c, r * 0.86)
		return
	if skin == "cat":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(-r, -r * 1.3), c + Vector2(-r * 0.15, -r * 0.7)]), tint)
		draw_colored_polygon(PackedVector2Array([c + Vector2(r, -r * 0.3), c + Vector2(r, -r * 1.3), c + Vector2(r * 0.15, -r * 0.7)]), tint)
	circle(c, r, tint)
	circle(c + Vector2(-r * 0.3, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.13))
	if skin == "robot":
		draw_style_box(_box(Color("25314c"), 8), Rect2(c - Vector2(r * 0.8, r * 0.4), Vector2(r * 1.6, r * 0.8)))
		draw_line(c + Vector2(0, -r), c + Vector2(0, -r * 1.5), tint, 4)
		circle(c + Vector2(0, -r * 1.5), 5, Color("ffd577"))
	if skin == "ninja":
		draw_rect(Rect2(c - Vector2(r, r * 0.36), Vector2(r * 2, r * 0.8)), Color("25314c"))
	if skin == "royal":
		var pts = PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.65), c + Vector2(-r * 0.8, -r * 1.35), c + Vector2(-r * 0.25, -r), c + Vector2(0, -r * 1.5), c + Vector2(r * 0.25, -r), c + Vector2(r * 0.8, -r * 1.35), c + Vector2(r * 0.7, -r * 0.65)])
		draw_colored_polygon(pts, Color("ffd577"))
	for side in [-1, 1]:
		var eye = c + Vector2(side * r * 0.33, -r * 0.1)
		circle(eye, r * (0.18 if skin == "alien" else 0.11), Color("11182b") if skin != "robot" else Color("6ce5bc"))
	if skin != "ninja":
		draw_arc(c + Vector2(0, r * 0.12), r * 0.27, 0.2, PI - 0.2, 16, Color("11182b"), 3, true)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	return b

func circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color, true, -1, true)

func ellipse(center: Vector2, radius: float, stretch: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, stretch)
	circle(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO)

func draw_animal(c: Vector2, r: float) -> void:
	var fur: Color = {"rabbit": Color("fff3e6"), "koala": Color("a6b2bc"), "panda": Color("fff9ed"), "capybara": Color("ba885a")}[skin]
	var ink = Color("26313e")
	for side in [-1, 1]:
		if skin == "rabbit":
			var ear = Rect2(c + Vector2(side * r * 0.49 - r * 0.24, -r * 1.9), Vector2(r * 0.48, r * 1.45))
			draw_style_box(_box(fur, int(r * 0.24)), ear)
			draw_style_box(_box(Color("f2b3bd"), int(r * 0.12)), Rect2(ear.position + Vector2(r * 0.12, r * 0.18), Vector2(r * 0.24, r * 0.9)))
		elif skin == "koala":
			circle(c + Vector2(side * r * 0.92, -r * 0.62), r * 0.53, fur)
			circle(c + Vector2(side * r * 0.98, -r * 0.62), r * 0.33, Color("dce1e5"))
		elif skin == "panda":
			circle(c + Vector2(side * r * 0.74, -r * 0.79), r * 0.39, ink)
		else:
			circle(c + Vector2(side * r * 0.75, -r * 0.76), r * 0.27, fur.darkened(0.12))
			circle(c + Vector2(side * r * 0.75, -r * 0.76), r * 0.14, Color("dba785"))
	if skin == "capybara":
		draw_style_box(_box(fur, int(r * 0.55)), Rect2(c - Vector2(r, r * 0.82), Vector2(r * 2, r * 1.8)))
		ellipse(c + Vector2(0, r * 0.3), r * 0.66, Vector2(1.17, 0.8), Color("d6a875"))
	else:
		circle(c, r, fur)
	circle(c + Vector2(-r * 0.32, -r * 0.4), r * 0.19, Color(1, 1, 1, 0.18))
	for side in [-1, 1]:
		var eye = c + Vector2(side * r * 0.39, -r * 0.12)
		if skin == "panda":
			ellipse(eye + Vector2(side * r * 0.035, r * 0.01), r * 0.27, Vector2(0.86, 1.1), ink)
			circle(eye, r * 0.105, Color.WHITE)
			circle(eye + Vector2(r * 0.025, 0), r * 0.06, ink)
		else:
			circle(eye, r * 0.09, ink)
			circle(eye - Vector2(r * 0.023, r * 0.023), r * 0.025, Color.WHITE)
		if skin == "rabbit":
			ellipse(c + Vector2(side * r * 0.57, r * 0.24), r * 0.14, Vector2(1.25, 0.6), Color("f2b3bd"))
	if skin == "koala":
		ellipse(c + Vector2(0, r * 0.08), r * 0.27, Vector2(0.75, 1.23), ink)
	elif skin == "capybara":
		for side in [-1, 1]:
			circle(c + Vector2(side * r * 0.105, r * 0.25), r * 0.035, Color("634632"))
		draw_line(c + Vector2(-r * 0.2, r * 0.53), c + Vector2(r * 0.2, r * 0.53), Color("634632"), 2, true)
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.14, r * 0.17), c + Vector2(r * 0.14, r * 0.17), c + Vector2(0, r * 0.33)]), Color("d58d9b") if skin == "rabbit" else ink)
	if skin != "capybara":
		draw_arc(c + Vector2(0, r * 0.28), r * 0.2, 0.15, PI - 0.15, 16, ink, 2, true)
	# Shared player-color scarf keeps each seat recognizable in every animal skin.
	draw_style_box(_box(tint, int(r * 0.1)), Rect2(c + Vector2(-r * 0.69, r * 0.73), Vector2(r * 1.38, r * 0.26)))
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.32, r * 0.85), c + Vector2(r * 0.69, r * 0.84), c + Vector2(r * 0.72, r * 1.3), c + Vector2(r * 0.4, r * 1.2)]), tint)
