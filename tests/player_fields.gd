extends Node
const Arena = preload("res://games/arena.gd")
const Darkspots = preload("res://games/darkspots.gd")
var checks = 0
var failures = 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)

func _ready() -> void:
	Party.sound = false
	Music.set_enabled(false)
	Music.player.stop()
	for dimensions in [Vector2(720, 1280), Vector2(1280, 720)]:
		for mask in range(1, 16):
			var game = Darkspots.new()
			for id in range(4):
				if mask & (1 << id):
					game.roster.append({"id": id, "bot": false, "skin": "classic", "color": Party.COLORS[id]})
			add_child(game)
			game.set_process(false)
			game.size = dimensions
			game.queue_redraw()
			for frame in range(3):
				await get_tree().process_frame
			var fields: Array = []
			for p in game.roster:
				var field: Rect2 = game.player_field(p.id)
				check(Rect2(Vector2.ZERO, dimensions).encloses(field), "Field inside viewport")
				check(field.encloses(game.board_square(p.id)), "Visible gold board inside matching player field")
				check(game.corner_at(game.pads[p.id].get_center()) == p.id, "Finger routes to matching player")
				if game.roster.size() >= 3:
					check((field.get_center().x < dimensions.x / 2) == (game.pads[p.id].get_center().x < dimensions.x / 2), "Board and finger on same left/right side")
					check((field.get_center().y < dimensions.y / 2) == (game.pads[p.id].get_center().y < dimensions.y / 2), "Board and finger on same upper/lower side")
				for other in fields:
					check(not field.intersects(other), "Player fields do not overlap")
				fields.append(field)
			game.queue_free()
			await get_tree().process_frame
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	print("FIELDS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
