extends Control
const Palette = preload("res://ui/game_palette.gd")
const Food = preload("res://games/ingredient.gd")
var game_id: String = "sprint"
var phase: float = 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
func _process(delta: float) -> void:
	phase += delta
	queue_redraw()
func rounded(rect: Rect2, color: Color, radius: int = 14) -> void:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	draw_style_box(b, rect)
func word(value: String, p: Vector2, font_size: int, ink: Color) -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, p - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
func _draw() -> void:
	var c: Vector2 = size / 2
	match game_id:
		"sprint":
			rounded(Rect2(Vector2.ZERO, size), Color("62cb8c"))
			for i in range(8):
				draw_circle(Vector2(fmod(i * 43.0 + 17, size.x), 8 + (i % 2) * (size.y - 16)), 8, Color("4db27a"), true, -1, true)
			rounded(Rect2(10, 24, size.x - 20, size.y - 42), Color("879bb3"), 16)
			draw_dashed_line(Vector2(15, c.y + 3), Vector2(size.x - 15, c.y + 3), Color("c5d8e8"), 2, 10, true)
			for i in range(5):
				draw_rect(Rect2(size.x - 29 + (i % 2) * 7, 28 + i * 14, 7, 14), Color.WHITE)
			for i in range(2):
				var p = Vector2(32 + (sin(phase * 1.1 + i) + 1) * 0.5 * (size.x - 88), 44 + i * 41)
				draw_circle(p + Vector2(0, 3), 16, Color(0, 0, 0, 0.2), true, -1, true)
				draw_circle(p, 15, Color("b3a0ff") if i == 0 else Color("ffb276"), true, -1, true)
				for side in [-1, 1]:
					draw_circle(p + Vector2(side * 5, -2), 2, Color("11182b"), true, -1, true)
				draw_arc(p + Vector2(0, 2), 5, 0.1, PI - 0.1, 12, Color("11182b"), 2, true)
		"signal":
			rounded(Rect2(Vector2.ZERO, size), Color("526ac8"))
			for i in range(10):
				var v = Vector2.from_angle(i * TAU / 10)
				draw_line(c + v * 46, c + v * 50, Color("a7b4ff"), 2, true)
			var ready: bool = fmod(phase, 3.0) > 1.6
			draw_circle(c, 35 + sin(phase * 3) * 2, Color("6ce5bc") if ready else Color("ffb276"), true, -1, true)
			word("TAP!" if ready else "WAIT", c + Vector2(0, 7), 20, Color("172343"))
			draw_arc(c, 44, -PI / 2, -PI / 2 + fmod(phase, 3.0) / 3 * TAU, 48, Color.WHITE, 3, true)
		"pairs":
			rounded(Rect2(Vector2.ZERO, size), Color("edb257"))
			var tile = Vector2(minf(46, (size.x - 36) / 4), 29)
			var start = c - Vector2(tile.x * 4 + 18, tile.y * 3 + 12) / 2
			for i in range(12):
				var p = start + Vector2(i % 4, floori(float(i) / 4)) * (tile + Vector2(6, 6))
				var face: bool = i == 1 or i == 6
				var flip: float = (sin(phase * 1.5) + 1) / 2 if face else 0.0
				var w: float = maxf(0.04, absf(cos(flip * PI))) * tile.x
				var rect = Rect2(p + Vector2((tile.x - w) / 2, 0), Vector2(w, tile.y))
				rounded(Rect2(rect.position + Vector2(0, 2), rect.size), Color("a97534"), 5)
				rounded(rect, Color("6acbde") if flip > 0.5 else Color("fff0c8"), 5)
				if flip > 0.6 and face:
					draw_circle(p + tile / 2, 7, Color("ffd577"), true, -1, true)
				elif w > tile.x * 0.6:
					word("?", p + tile / 2 + Vector2(0, 6), 19, Color("b88039"))
		"burger":
			rounded(Rect2(Vector2.ZERO, size), Color("87d3ee"))
			for i in range(3):
				draw_circle(Vector2(fmod(phase * 7 + i * 90, size.x + 40) - 20, 17 + i * 9), 19, Color(1, 1, 1, 0.35), true, -1, true)
			rounded(Rect2(0, size.y - 15, size.x, 15), Color("edb784"), 0)
			rounded(Rect2(c.x - 55, size.y - 22, 110, 9), Color("f8fcff"), 5)
			for i in range(5):
				draw_set_transform(Vector2(c.x + sin(phase * 1.5 + i * 0.3) * i * 1.5, size.y - 30 - i * 17), sin(phase * 1.5) * i * 0.008, Vector2(0.8, 0.8))
				Food.draw_food(self, [5, 2, 3, 1, 0][i], 108, 22)
			draw_set_transform(Vector2.ZERO)

		"darkspots":
			rounded(Rect2(Vector2.ZERO, size), Color("d6b6ed"))
			var side: float = minf(size.y - 30, size.x - 40)
			var square = Rect2(c - Vector2.ONE * side / 2, Vector2.ONE * side)
			draw_texture_rect(Palette.rainbow_square(), square, false)
			var script = preload("res://games/darkspots.gd")
			var target = script.perimeter_point(square, 0.62)
			var marker = script.perimeter_point(square, fposmod(phase * 0.48, 1))
			var length: float = 0.09 + sin(phase * 0.6) * 0.0275
			draw_polyline(script.perimeter_range(square, 0.62, length), Color("805614"), 16, true)
			draw_polyline(script.perimeter_range(square, 0.62, length), Color("ffd15c"), 13, true)
			draw_arc(marker, 11, 0, TAU, 32, Color("17243c"), 8, true)
			draw_arc(marker, 11, 0, TAU, 32, Color("b3a0ff"), 5, true)
			draw_circle(marker, 4, Color("b3a0ff"), true, -1, true)

		"obby":
			rounded(Rect2(Vector2.ZERO, size), Color("31496c"))
			var ground: float = size.y - 20
			draw_line(Vector2(10, ground), Vector2(size.x - 10, ground), Color("9baec8"), 3, true)
			var hop: float = maxf(0, sin(phase * 3)) * 35
			draw_circle(Vector2(size.x * 0.25, ground - 19 - hop), 14, Color("ff8fb8"), true, -1, true)
			for j in range(2):
				var x: float = fposmod(size.x - phase * 55 + j * size.x / 2, size.x)
				rounded(Rect2(x, ground - 22 if j == 0 else ground - 57, 22, 22), Color("ffb276") if j == 0 else Color("f6d36f"), 4)
			word("JUMP ↑    DUCK ↓", Vector2(size.x / 2, 23), 15, Color.WHITE)

		"snake":
			rounded(Rect2(Vector2.ZERO, size), Color("23504b"))
			for player in range(2):
				var color = Color("b3a0ff") if player == 0 else Color("6ce5bc")
				for segment in range(10):
					var point = Vector2(size.x * (0.25 + player * 0.5) + sin(phase * 2 - segment * 0.35 + player) * 22, 25 + segment * 8)
					draw_circle(point, 7, color, true, -1, true)
					if segment == 0:
						draw_circle(point + Vector2(-2, -2), 2, Color.WHITE, true, -1, true)
						draw_circle(point + Vector2(3, -2), 2, Color.WHITE, true, -1, true)
			for i in range(3):
				var point = Vector2(size.x * 0.5 + (i - 1) * 30, size.y * (0.4 + i * 0.13))
				draw_colored_polygon(PackedVector2Array([point + Vector2(-8, -7), point + Vector2(8, -7), point + Vector2(0, 9)]), Color("ffd36a"))
				draw_line(point + Vector2(-8, -7), point + Vector2(8, -7), Color("d78a45"), 3, true)
				draw_circle(point, 2, Color("e35b5d"), true, -1, true)

		"dance":
			rounded(Rect2(Vector2.ZERO, size), Color("423358"))
			for i in range(5):
				var x: float = (i + 0.5) * size.x / 5
				draw_line(Vector2(x, 0), Vector2(x + sin(phase + i) * 26, size.y), Color(1, 0.6, 0.85, 0.08), 18, true)
			var hip = c + Vector2(0, 15 + sin(phase * 4) * 6)
			draw_circle(hip - Vector2(0, 32), 14, Color("f7a4d2"), true, -1, true)
			draw_line(hip - Vector2(0, 15), hip + Vector2(0, 12), Color("f7a4d2"), 9, true)
			for side in [-1, 1]:
				draw_line(hip + Vector2(0, 10), hip + Vector2(side * 19, 32), Color("f7a4d2"), 5, true)
				draw_line(hip - Vector2(0, 9), hip + Vector2(side * 32, sin(phase * 4 + side) * 18 - 20), Color.WHITE, 5, true)
			word("WAVE · JUMP · SPIN · CLAP", Vector2(c.x, size.y - 8), 12, Color("ffd577"))
