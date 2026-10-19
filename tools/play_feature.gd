extends Control
const Art = preload("res://ui/game_art.gd")
const Rainbow = preload("res://assets/rainbow.gdshader")

func _ready() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material = ShaderMaterial.new()
	material.shader = Rainbow
	bg.material = material
	add_child(bg)
	var plate = Panel.new()
	plate.position = Vector2(40, 48)
	plate.size = Vector2(454, 404)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("17213c")
	style.set_corner_radius_all(28)
	plate.add_theme_stylebox_override("panel", style)
	add_child(plate)
	for line in [["4 PLAYERS", 64, 78, 58, Color.WHITE], ["GAME", 64, 157, 66, Color.WHITE], ["OFFLINE", 64, 236, 66, Color("ffd577")], ["One screen. Everyone plays.", 66, 338, 23, Color("c7d1e9")], ["1–4 players · 8 mini-games", 66, 381, 22, Color("6ce5bc")]]:
		var text = Label.new()
		text.text = line[0]
		text.position = Vector2(line[1], line[2])
		text.add_theme_font_size_override("font_size", line[3])
		text.add_theme_color_override("font_color", line[4])
		add_child(text)
	var games: Array = [["snake", "Snake Clash"], ["burger", "BurgerTower"], ["pairs", "Pair Peek"], ["dance", "Let's Dance!"]]
	for i in range(games.size()):
		var pos = Vector2(528 + (i % 2) * 232, 58 + floori(i / 2.0) * 208)
		var art = Art.new()
		art.game_id = games[i][0]
		art.position = pos
		art.size = Vector2(216, 150)
		add_child(art)
		art.phase = 1.25
		art.set_process(false)
		var text = Label.new()
		text.text = games[i][1]
		text.position = pos + Vector2(0, 155)
		text.size.x = 216
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 23)
		text.add_theme_color_override("font_color", Color("302245"))
		add_child(text)
